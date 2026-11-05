# frozen_string_literal: true

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      # Abstract base class for test distribution strategies.
      # Subclasses implement different ways of assigning tests to workers.
      class TestDistributor
        # Add a test to be distributed to workers.
        # @param test [Array] Test tuple: [class, method, reporter]
        def add_test(test)
          raise NotImplementedError
        end

        # Retrieve the next test for a specific worker.
        # @param worker_id [Integer] The worker requesting work
        # @return [Array, nil] Test tuple or nil if no work available
        def take(worker_id:)
          raise NotImplementedError
        end

        # Clear all pending work (called on interrupt).
        def interrupt
          # Optional
        end

        # Check if there is pending work.
        # @return [Boolean] true if work is pending
        def pending?
          raise NotImplementedError
        end

        # Close the distributor. No more work will be accepted.
        def close
          # Optional
        end
      end

      # Shared queue distributor - workers compete for tests (work stealing).
      # Internal/testing helper; not exposed as a public distribution mode.
      class SharedQueueDistributor < TestDistributor
        def initialize
          @queue = Queue.new
        end

        def add_test(test)
          @queue << test
        end

        def take(...)
          @queue.pop
        end

        def interrupt
          @queue.clear
        end

        def pending?
          !@queue.empty?
        end

        def close
          @queue.close
        end
      end

      # Round-robin distributor - tests are assigned to workers as they arrive.
      #
      # Tests arrive already shuffled by Minitest based on the seed. Since the arrival
      # order is deterministic for a given seed, round-robin assignment produces
      # reproducible test-to-worker distribution.
      #
      # This is much simpler than buffering and re-shuffling: tests can start executing
      # immediately as they arrive, and we avoid complex synchronization.
      class RoundRobinDistributor < TestDistributor
        WORK_WAIT_TIMEOUT = 0.1

        def initialize(worker_count:)
          @worker_count = worker_count
          @queues = Array.new(@worker_count) { Queue.new }
          @next_worker = 0
          @mutex = Mutex.new
          @cv = ConditionVariable.new
          @closed = false
        end

        def add_test(test)
          @mutex.synchronize do
            return if @closed || !@queues

            worker_id = @next_worker
            @next_worker = (@next_worker + 1) % @worker_count
            queue = @queues[worker_id]
            queue << test unless queue.closed?
            @cv.signal  # Wake one waiting worker
          end
        end

        def take(worker_id:)
          job = nil

          until job || exhausted?(worker_id)
            job = next_job(worker_id)
            wait(worker_id) unless job || exhausted?(worker_id)
          end

          job
        end

        def interrupt
          @mutex.synchronize do
            @queues&.each do |q|
              q.clear
              q.close
            end
            @closed = true
            @cv.broadcast  # Wake all waiting workers
          end
        end

        def pending?
          @mutex.synchronize do
            @queues&.any? { |q| !q.empty? }
          end
        end

        def close
          @mutex.synchronize do
            @queues&.each(&:close)
            @closed = true
            @cv.broadcast  # Wake all waiting workers
          end
        end

        private
          def next_job(worker_id)
            pop_now(worker_id)
          end

          def pop_now(worker_id)
            @queues[worker_id].pop(true)
          rescue ThreadError, ClosedQueueError
            nil
          end

          # Waits for work, rechecking exhausted? inside the mutex to handle
          # the race where close() broadcasts before we start waiting.
          def wait(worker_id)
            @mutex.synchronize do
              @cv.wait(@mutex, WORK_WAIT_TIMEOUT) unless exhausted?(worker_id)
            end
          end

          def exhausted?(worker_id)
            queue = @queues[worker_id]
            queue.closed? && queue.empty?
          end
      end

      # Round-robin distributor with work stealing enabled.
      # Tests are initially assigned round-robin as they arrive (same as RoundRobinDistributor),
      # but when a worker exhausts its queue, it can steal work from other workers
      # to improve load balancing.
      class RoundRobinWorkStealingDistributor < RoundRobinDistributor
        private
          def next_job(worker_id)
            pop_now(worker_id) || steal(worker_id)
          end

          def steal(worker_id)
            # Steal from other workers in a consistent order
            @worker_count.times do |offset|
              other_id = (worker_id + offset + 1) % @worker_count
              if job = pop_now(other_id)
                return job
              end
            end

            nil
          end

          def exhausted?(...)
            @queues.all? { |q| q.closed? && q.empty? }
          end
      end
    end
  end
end
