module ActiveSupport
  module Testing
    module Isolation
      require 'thread'

      def self.included(klass) #:nodoc:
        klass.class_eval do
          parallelize_me!
        end
      end

      def self.forking_env?
        !ENV["NO_FORK"] && Process.respond_to?(:fork)
      end

      def run
        serialized = run_in_isolation do
          super
        end

        Marshal.load(serialized)
      end

      module Forking
        def run_in_isolation(&blk)
          read, write = IO.pipe
          read.binmode
          write.binmode

          pid = fork do
            read.close
            yield
            begin
              if error?
                failures.map! { |e|
                  begin
                    Marshal.dump e
                    e
                  rescue TypeError
                    ex = Exception.new e.message
                    ex.set_backtrace e.backtrace
                    Minitest::UnexpectedError.new ex
                  end
                }
              end
              result = Marshal.dump(self.dup)
            end

            write.puts [result].pack("m")
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
            yield
            File.open(ENV["ISOLATION_OUTPUT"], "w") do |file|
              file.puts [Marshal.dump(self.dup)].pack("m")
            end
            exit!
          else
            Tempfile.open("isolation") do |tmpfile|
              env = {
                'ISOLATION_TEST' => self.class.name,
                'ISOLATION_OUTPUT' => tmpfile.path
              }

              load_paths = $-I.map {|p| "-I\"#{File.expand_path(p)}\"" }.join(" ")
              orig_args = ORIG_ARGV.join(" ")
              test_opts = "-n#{self.class.name}##{self.name}"
              command = "#{Gem.ruby} #{load_paths} #{$0} '#{orig_args}' #{test_opts}"

              # IO.popen lets us pass env in a cross-platform way
              child = IO.popen(env, command)

              begin
                Process.wait(child.pid)
              rescue Errno::ECHILD # The child process may exit before we wait
                nil
              end

              return tmpfile.read.unpack("m")[0]
            end
          end
        end
      end

      include forking_env? ? Forking : Subprocess
    end
  end
end
