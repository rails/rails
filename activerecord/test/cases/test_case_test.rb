# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class TestCaseLeakCheckTest < ActiveRecord::TestCase
    include WaitForTestHelper

    self.use_transactional_tests = false

    def test_check_connection_leaks_does_not_report_connections_held_for_reaper_maintenance
      pool = ActiveRecord::Base.connection_pool

      conn = ActiveRecord::Base.lease_connection
      conn.select_value("SELECT 1")
      ActiveRecord::Base.connection_handler.clear_active_connections!

      assert_not_nil conn

      release_maintenance_latch = Concurrent::CountDownLatch.new(1)
      leak_check_attempted_latch = Concurrent::CountDownLatch.new(1)

      maintenance_thread = Thread.new do
        Thread.current.name = "AR Pool Reaper"

        pool.reaper_lock do
          pool.send(:checkout_for_maintenance, conn)
          release_maintenance_latch.wait
          pool.send(:return_from_maintenance, conn)
        end
      end

      wait_for(message: "connection was not checked out for maintenance", timeout: 1) do
        conn.in_use?
      end
      assert_not_equal ActiveSupport::IsolatedExecutionState.context, conn.owner

      original_reaper_lock_method = pool.method(:reaper_lock)
      leak_check_thread = nil

      pool.stub(:reaper_lock, ->(&block) do
        leak_check_attempted_latch.count_down
        original_reaper_lock_method.call(&block)
      end) do
        leak_check_thread = Thread.new do
          check_connection_leaks
        end

        wait_for(message: "leak check did not reach the reaper lock", timeout: 1) do
          !leak_check_thread.alive? || leak_check_attempted_latch.wait(0)
        end

        release_maintenance_latch.count_down
        assert_nothing_raised do
          leak_check_thread.value
        end
      end
    ensure
      release_maintenance_latch&.count_down
      maintenance_thread&.join
      leak_check_thread&.join

      if conn&.in_use?
        conn.steal!
        pool.checkin(conn)
      end
    end
  end
end
