require 'rbconfig'
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
      def initialize
        @calls = []
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

      def method_missing(name, *args)
        @calls << [name, args]
      end
    end

    module Isolation
      def self.forking_env?
        !ENV["NO_FORK"] && ((RbConfig::CONFIG['host_os'] !~ /mswin|mingw/) && (RUBY_PLATFORM !~ /java/))
      end

      def self.included(base)
        if defined?(::MiniTest) && base < ::MiniTest::Unit::TestCase
          base.send :include, MiniTest
        elsif defined?(Test::Unit)
          base.send :include, TestUnit
        end
      end

      def _run_class_setup      # class setup method should only happen in parent
        unless defined?(@@ran_class_setup) || ENV['ISOLATION_TEST']
          self.class.setup if self.class.respond_to?(:setup)
          @@ran_class_setup = true
        end
      end

      module TestUnit
        def run(result)
          _run_class_setup

          yield(Test::Unit::TestCase::STARTED, name)

          @_result = result

          serialized = run_in_isolation do |proxy|
            begin
              super(proxy) { }
            rescue Exception => e
              proxy.add_error(Test::Unit::Error.new(name, e))
            end
          end

          retval, proxy = Marshal.load(serialized)
          proxy.__replay__(@_result)

          yield(Test::Unit::TestCase::FINISHED, name)
          retval
        end
      end

      module MiniTest
        def run(runner)
          _run_class_setup

          serialized = run_in_isolation do |isolated_runner|
            super(isolated_runner)
          end

          retval, proxy = Marshal.load(serialized)
          proxy.__replay__(runner)
          retval
        end
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

# Only in subprocess for windows / jruby.
if ENV['ISOLATION_TEST']
  require "test/unit/collector/objectspace"
  class Test::Unit::Collector::ObjectSpace
    def include?(test)
      super && test.method_name == ENV['ISOLATION_TEST']
    end
  end
end
