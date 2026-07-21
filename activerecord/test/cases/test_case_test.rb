# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class TestCaseLeakCheckTest < ActiveRecord::TestCase
    include WaitForTestHelper

    self.use_transactional_tests = false

    def test_check_connection_leaks_does_not_report_connections_held_for_reaper_maintenance
      with_temporary_connection_pool do
        pool = ActiveRecord::Base.connection_pool

        conn = pool.checkout
        conn.select_value("SELECT 1")
        pool.checkin(conn)

        assert_not_nil conn

        release_maintenance = Concurrent::Event.new
        leak_check_attempted = Concurrent::Event.new

        maintenance_thread = Thread.new do
          Thread.current.name = "AR Pool Reaper"

          pool.reaper_lock do
            pool.send(:checkout_for_maintenance, conn)
            release_maintenance.wait
            pool.send(:return_from_maintenance, conn)
          end
        end

        wait_for(message: "connection was not checked out for maintenance", timeout: 1) do
          conn.in_use?
        end
        assert_not_equal ActiveSupport::IsolatedExecutionState.context, conn.owner

        original_reaper_lock_method = pool.method(:reaper_lock)

        pool.stub(:reaper_lock, ->(&block) do
          leak_check_attempted.set
          original_reaper_lock_method.call(&block)
        end) do
          leak_check_thread = Thread.new do
            check_connection_leaks([pool])
          end

          wait_for(message: "leak check did not reach the reaper lock", timeout: 1) do
            !leak_check_thread.alive? || leak_check_attempted.wait(0)
          end

          release_maintenance.set
          assert_nothing_raised do
            leak_check_thread.value
          end
        ensure
          release_maintenance.set
          leak_check_thread&.join
        end
      ensure
        release_maintenance&.set
        maintenance_thread&.join

        if conn&.in_use?
          conn.steal!
          pool.checkin(conn)
        end
      end
    end

    def test_check_connection_leaks_does_not_report_connections_held_for_async_reaper_maintenance
      with_temporary_connection_pool do
        pool = ActiveRecord::Base.connection_pool
        original_async_executor = pool.async_executor

        async_executor = FakeAsyncExecutor.new
        pool.instance_variable_set(:@async_executor, async_executor)

        conn = pool.checkout
        conn.select_value("SELECT 1")
        pool.checkin(conn)

        maintenance_started = Concurrent::Event.new
        release_maintenance = Concurrent::Event.new

        pool.reaper_lock do
          pool.send(:sequential_maintenance, ->(candidate) { candidate.equal?(conn) }) do
            maintenance_started.set
            release_maintenance.wait
          end
        end

        maintenance_started.wait
        assert_predicate conn, :in_use?
        assert_not_equal ActiveSupport::IsolatedExecutionState.context, conn.owner

        original_wait_method = method(:wait_for_pool_maintenance)

        stub(:wait_for_pool_maintenance, ->(waiting_pool) do
          if waiting_pool.equal?(pool)
            assert_predicate conn, :in_use?
            release_maintenance.set
            original_wait_method.call(waiting_pool)
            assert_not_predicate conn, :in_use?
          else
            original_wait_method.call(waiting_pool)
          end
        end) do
          check_connection_leaks([pool])
        end
      ensure
        release_maintenance&.set
        async_executor&.threads&.each(&:join)
        pool&.instance_variable_set(:@async_executor, original_async_executor)

        if conn&.in_use?
          conn.steal!
          pool.checkin(conn)
        end
      end
    end

    class FakeAsyncExecutor
      attr_reader :threads

      def initialize
        @threads = []
        @mutex = Mutex.new
        @scheduled_task_count = 0
        @completed_task_count = 0
      end

      def post(&block)
        @mutex.synchronize do
          @scheduled_task_count += 1
        end

        @threads << Thread.new do
          block.call
        ensure
          @mutex.synchronize do
            @completed_task_count += 1
          end
        end
      end

      def scheduled_task_count
        @mutex.synchronize do
          @scheduled_task_count
        end
      end

      def completed_task_count
        @mutex.synchronize do
          @completed_task_count
        end
      end
    end
  end
end
