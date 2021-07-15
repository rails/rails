# frozen_string_literal: true

module ActiveSupport
  module Testing
    class ParallelizeExecutor # :nodoc:
      attr_reader :size, :parallelize_with, :parallel_executor

      def initialize(size:, with:)
        @size = size
        @parallelize_with = with
        @parallel_executor = build_parallel_executor
      end

      def start
        parallelize if should_parallelize?
        show_execution_info

        parallel_executor.start if parallelized?
      end

      def <<(work)
        parallel_executor << work if parallelized?
      end

      def shutdown
        parallel_executor.shutdown if parallelized?
      end

      private
        def build_parallel_executor
          case parallelize_with
          when :processes
            Testing::Parallelization.new(size)
          when :threads
            ActiveSupport::TestCase.lock_threads = false if defined?(ActiveSupport::TestCase.lock_threads)
            Minitest::Parallel::Executor.new(size)
          else
            raise ArgumentError, "#{parallelize_with} is not a supported parallelization executor."
          end
        end

        def parallelize
          @parallelized = true
          Minitest::Test.parallelize_me!
        end

        def parallelized?
          @parallelized
        end

        def should_parallelize?
          ENV["PARALLEL_WORKERS"] || tests_count > ActiveSupport.test_parallelization_minimum_number_of_tests
        end

        def tests_count
          @tests_count ||= Minitest::Runnable.runnables.sum { |runnable| runnable.runnable_methods.size }
        end

        def show_execution_info
          puts execution_info
        end

        def execution_info
          if parallelized?
            "Running #{tests_count} tests in parallel using #{parallel_executor.size} #{parallelize_with}"
          else
            "Running #{tests_count} tests in a single process (parallelization threshold is #{ActiveSupport.test_parallelization_minimum_number_of_tests})"
          end
        end
    end
  end
end
