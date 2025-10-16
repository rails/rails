# frozen_string_literal: true

require_relative "../abstract_unit"
require "concurrent/atomic/count_down_latch"
require "active_support/concurrency/thread_monitor"

module ActiveSupport
  module Concurrency
    class ThreadMonitorTest < ActiveSupport::TestCase
      def setup
        @monitor = ThreadMonitor.new
      end

      def test_synchronize_blocks_other_threads
        blocked = false
        ready_latch = Concurrent::CountDownLatch.new
        blocked_latch = Concurrent::CountDownLatch.new

        thread1 = Thread.new do
          @monitor.synchronize do
            ready_latch.count_down
            blocked_latch.wait
            sleep 0.1
          end
        end

        thread2 = Thread.new do
          ready_latch.wait
          @monitor.synchronize do
            blocked = true
          end
        end

        sleep 0.05 # Give thread2 time to try to acquire the lock
        assert_not blocked, "Thread should be blocked waiting for monitor"

        blocked_latch.count_down
        thread1.join
        thread2.join

        assert blocked, "Thread should have acquired monitor after first thread released it"
      end

      def test_reentrant_locking
        count = 0
        @monitor.synchronize do
          count += 1
          @monitor.synchronize do
            count += 1
            @monitor.synchronize do
              count += 1
            end
          end
        end
        assert_equal 3, count
      end

      def test_lock_owned_by_current_thread
        @monitor.synchronize do
          # Test that we can create an enumerator that also tries to acquire the lock
          # This should work because the same thread already owns the lock
          enumerator = Enumerator.new do |yielder|
            @monitor.synchronize do
              yielder.yield 42
            end
          end
          assert_equal 42, enumerator.next
        end
      end

      def test_exception_handling_releases_lock
        exception_raised = false
        subsequent_lock_acquired = false

        begin
          @monitor.synchronize do
            raise StandardError, "test exception"
          end
        rescue StandardError
          exception_raised = true
        end

        assert exception_raised

        # Ensure the lock was properly released
        @monitor.synchronize do
          subsequent_lock_acquired = true
        end

        assert subsequent_lock_acquired
      end

      def test_thread_error_on_wrong_thread_unlock
        @monitor.synchronize do
          thread = Thread.new do
            assert_raises(ThreadError) do
              @monitor.send(:mon_exit)
            end
          end
          thread.join
        end
      end
    end
  end
end
