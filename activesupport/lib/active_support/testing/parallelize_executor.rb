# frozen_string_literal: true

module ActiveSupport
  module Testing
    class ParallelizeExecutor # :nodoc:
      attr_reader :size, :parallelize_with, :threshold

      def initialize(size:, with:, threshold: ActiveSupport.test_parallelization_threshold)
        @size = size
        @parallelize_with = with
        @threshold = threshold
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
        def parallel_executor
          @parallel_executor ||= build_parallel_executor
        end

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
          parallel_test_suites.map(&:parallelize_me!)
        end

        def parallelized?
          @parallelized if defined?(@parallelized)
        end

        def should_parallelize?
          ENV["PARALLEL_WORKERS"] || tests_count[:parallel] > threshold
        end

        def parallel_test_suites
          Minitest::Runnable.runnables.select { |runnable| runnable.test_order == :parallel && !runnable.runnable_methods.empty? }
        end

        def tests_count
          @tests_count ||= begin
            suites = Minitest::Runnable.runnables.reject { |s| s.runnable_methods.empty? }
            parallel, serial = suites.partition { |s| s.test_order == :parallel }
            {
              parallel: parallel.sum(&method(:runnable_tests_count)),
              serial: serial.sum(&method(:runnable_tests_count))
            }
          end
        end

        def runnable_tests_count(runnable)
          runnable.runnable_methods.size
        end

        def show_execution_info
          puts execution_info
        end

        def execution_info
          if parallelized?
            parallelized_execution_info = "Running #{tests_count[:parallel]} tests in parallel using #{parallel_executor.size} #{parallelize_with}"
            tests_count[:serial] > 0 ? parallelized_execution_info + " and #{tests_count[:serial]} serial tests." : parallelized_execution_info
          else
            "Running #{tests_count.values.sum} tests in a single process (parallelization threshold is #{threshold})"
          end
        end
    end
  end
end
