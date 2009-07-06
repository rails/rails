module ActiveSupport
  module Testing
    class ProxyTestResult
      def initialize
        @calls = []
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
        !ENV["NO_FORK"] && RUBY_PLATFORM !~ /mswin|mingw|java/
      end

      def run(result)
        unless defined?(@@ran_class_setup)
          self.class.setup if self.class.respond_to?(:setup)
          @@ran_class_setup = true
        end

        yield(Test::Unit::TestCase::STARTED, name)

        @_result = result

        proxy = run_in_isolation do |proxy|
          super(proxy) { }
        end

        proxy.__replay__(@_result)

        yield(Test::Unit::TestCase::FINISHED, name)
      end

      module Forking
        def run_in_isolation(&blk)
          read, write = IO.pipe

          pid = fork do
            read.close
            proxy = ProxyTestResult.new
            yield proxy
            write.puts [Marshal.dump(proxy)].pack("m")
            exit!
          end

          write.close
          result = read.read
          Process.wait2(pid)
          Marshal.load(result.unpack("m")[0])
        end
      end

      module Subprocess
        # Crazy H4X to get this working in windows / jruby with
        # no forking.
        def run_in_isolation(&blk)
          require "tempfile"

          if ENV["ISOLATION_TEST"]
            proxy = ProxyTestResult.new
            yield proxy
            File.open(ENV["ISOLATION_OUTPUT"], "w") do |file|
              file.puts [Marshal.dump(proxy)].pack("m")
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

              return Marshal.load(tmpfile.read.unpack("m")[0])
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