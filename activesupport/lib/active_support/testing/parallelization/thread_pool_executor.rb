# frozen_string_literal: true

require "concurrent/executor/fixed_thread_pool"

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      # Thread pool executor using a test distributor strategy.
      # Provides the same interface as Minitest::Parallel::Executor but
      # with configurable distribution (round robin vs work stealing).
      class ThreadPoolExecutor
        attr_reader :size

        def initialize(size:, distributor:)
          @size = size
          @distributor = distributor
          @pool = Concurrent::FixedThreadPool.new(size, fallback_policy: :abort)
        end

        def start
          size.times do |worker_id|
            @pool.post { worker_loop(worker_id) }
          end
        end

        def <<(work)
          @distributor.add_test(work)
        end

        def shutdown
          @distributor.close
          @pool.shutdown
          @pool.wait_for_termination
        end

        private
          def worker_loop(worker_id)
            while job = @distributor.take(worker_id: worker_id)
              klass, method, reporter = job

              reporter.synchronize { reporter.prerecord klass, method }
              result = Minitest.run_one_method klass, method
              reporter.synchronize { reporter.record result }
            end
          end
      end
    end
  end
end
