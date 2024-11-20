# frozen_string_literal: true

require "active_support/testing/parallelize_executor"

module ActiveSupport
  module Testing
    module Isolation
      SubprocessCrashed = Class.new(StandardError)

      def self.included(klass) # :nodoc:
        klass.class_eval do
          parallelize_me! unless Minitest.parallel_executor.is_a?(ActiveSupport::Testing::ParallelizeExecutor)
        end
      end

      def self.forking_env?
        !ENV["NO_FORK"] && Process.respond_to?(:fork)
      end

      def run
        status, serialized = run_in_isolation do
          super
        end

        unless status&.success?
          error = SubprocessCrashed.new("Subprocess exited with an error: #{status.inspect}\noutput: #{serialized.inspect}")
          error.set_backtrace(caller)
          self.failures << Minitest::UnexpectedError.new(error)
          return defined?(Minitest::Result) ? Minitest::Result.from(self) : dup
        end

        Marshal.load(serialized)
      end

      module Forking
        def run_in_isolation(&blk)
          IO.pipe do |read, write|
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
                test_result = defined?(Minitest::Result) ? Minitest::Result.from(self) : dup
                result = Marshal.dump(test_result)
              end

              write.puts [result].pack("m")
              exit!(0)
            end

            write.close
            result = read.read
            _, status = Process.wait2(pid)
            return status, result.unpack1("m")
          end
        end
      end

      module Subprocess
        ORIG_ARGV = ARGV.dup unless defined?(ORIG_ARGV)

        # Complicated H4X to get this working in Windows / JRuby with
        # no forking.
        def run_in_isolation(&blk)
          require "tempfile"

          if ENV["ISOLATION_TEST"]
            yield
            test_result = defined?(Minitest::Result) ? Minitest::Result.from(self) : dup
            File.open(ENV["ISOLATION_OUTPUT"], "w") do |file|
              file.puts [Marshal.dump(test_result)].pack("m")
            end
            exit!(0)
          else
            Tempfile.open("isolation") do |tmpfile|
              env = {
                "ISOLATION_TEST" => self.class.name,
                "ISOLATION_OUTPUT" => tmpfile.path
              }

              test_opts = "-n#{self.class.name}##{name}"

              load_path_args = []
              $-I.each do |p|
                load_path_args << "-I"
                load_path_args << File.expand_path(p)
              end

              child = IO.popen([env, Gem.ruby, *load_path_args, $0, *ORIG_ARGV, test_opts])

              status = nil
              begin
                _, status = Process.wait2(child.pid)
              rescue Errno::ECHILD # The child process may exit before we wait
                nil
              end

              return status, tmpfile.read.unpack1("m")
            end
          end
        end
      end

      include forking_env? ? Forking : Subprocess
    end
  end
end
