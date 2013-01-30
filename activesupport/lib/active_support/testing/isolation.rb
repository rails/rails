require 'rbconfig'
begin
  require 'minitest/parallel_each'
rescue LoadError
end

module ActiveSupport
  module Testing
    class RemoteError < StandardError

      attr_reader :message, :backtrace

      def initialize(exception)
        @message = "caught #{exception.class.name}: #{exception.message}"
        @backtrace = exception.backtrace
      end
    end

    class ProxyTestResult
      def initialize(calls = [])
        @calls = calls
      end

      def add_error(e)
        e = Test::Unit::Error.new(e.test_name, RemoteError.new(e.exception))
        @calls << [:add_error, e]
      end

      def __replay__(result)
        @calls.each do |name, args|
          result.send(name, *args)
        end
      end

      def marshal_dump
        @calls
      end

      def marshal_load(calls)
        initialize(calls)
      end

      def method_missing(name, *args)
        @calls << [name, args]
      end
    end

    module Isolation
      require 'thread'

      # Recent versions of MiniTest (such as the one shipped with Ruby 2.0) already define
      # a ParallelEach class.
      unless defined? ParallelEach
        class ParallelEach
          include Enumerable

          # default to 2 cores
          CORES = (ENV['TEST_CORES'] || 2).to_i

          def initialize list
            @list  = list
            @queue = SizedQueue.new CORES
          end

          def grep pattern
            self.class.new super
          end

          def each
            threads = CORES.times.map {
              Thread.new {
                while job = @queue.pop
                  yield job
                end
              }
            }
            @list.each { |i| @queue << i }
            CORES.times { @queue << nil }
            threads.each(&:join)
          end
        end
      end

      def self.included(klass) #:nodoc:
        klass.extend(Module.new {
          def test_methods
            ParallelEach.new super
          end
        })
      end

      def self.forking_env?
        !ENV["NO_FORK"] && ((RbConfig::CONFIG['host_os'] !~ /mswin|mingw/) && (RUBY_PLATFORM !~ /java/))
      end

      @@class_setup_mutex = Mutex.new

      def _run_class_setup      # class setup method should only happen in parent
        @@class_setup_mutex.synchronize do
          unless defined?(@@ran_class_setup) || ENV['ISOLATION_TEST']
            self.class.setup if self.class.respond_to?(:setup)
            @@ran_class_setup = true
          end
        end
      end

      def run(runner)
        _run_class_setup

        serialized = run_in_isolation do |isolated_runner|
          super(isolated_runner)
        end

        retval, proxy = Marshal.load(serialized)
        proxy.__replay__(runner)
        retval
      end

      module Forking
        def run_in_isolation(&blk)
          read, write = IO.pipe

          pid = fork do
            read.close
            proxy = ProxyTestResult.new
            retval = yield proxy
            write.puts [Marshal.dump([retval, proxy])].pack("m")
            exit!
          end

          write.close
          result = read.read
          Process.wait2(pid)
          return result.unpack("m")[0]
        end
      end

      module Subprocess
        ORIG_ARGV = ARGV.dup unless defined?(ORIG_ARGV)

        # Crazy H4X to get this working in windows / jruby with
        # no forking.
        def run_in_isolation(&blk)
          require "tempfile"

          if ENV["ISOLATION_TEST"]
            proxy = ProxyTestResult.new
            retval = yield proxy
            File.open(ENV["ISOLATION_OUTPUT"], "w") do |file|
              file.puts [Marshal.dump([retval, proxy])].pack("m")
            end
            exit!
          else
            Tempfile.open("isolation") do |tmpfile|
              ENV["ISOLATION_TEST"]   = @method_name
              ENV["ISOLATION_OUTPUT"] = tmpfile.path

              load_paths = $-I.map {|p| "-I\"#{File.expand_path(p)}\"" }.join(" ")
              `#{Gem.ruby} #{load_paths} #{$0} #{ORIG_ARGV.join(" ")} -t\"#{self.class}\"`

              ENV.delete("ISOLATION_TEST")
              ENV.delete("ISOLATION_OUTPUT")

              return tmpfile.read.unpack("m")[0]
            end
          end
        end
      end

      include forking_env? ? Forking : Subprocess
    end
  end
end
