# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  class Mysql2NestedDeadlockTest < ActiveRecord::Mysql2TestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = "samples"
    end

    setup do
      @abort, Thread.abort_on_exception = Thread.abort_on_exception, false
      Thread.report_on_exception, @original_report_on_exception = false, Thread.report_on_exception

      connection = ActiveRecord::Base.connection
      connection.clear_cache!

      connection.create_table("samples", force: true) do |t|
        t.integer "value"
      end

      Sample.reset_column_information
    end

    teardown do
      ActiveRecord::Base.clear_active_connections!(:all)
      ActiveRecord::Base.connection.drop_table "samples", if_exists: true

      Thread.abort_on_exception = @abort
      Thread.report_on_exception = @original_report_on_exception
    end

    test "deadlock correctly raises Deadlocked inside nested SavepointTransaction" do
      connection = Sample.connection
      assert_raises(ActiveRecord::Deadlocked) do
        barrier = Concurrent::CyclicBarrier.new(2)

        s1 = Sample.create value: 1
        s2 = Sample.create value: 2

        begin
          thread = Thread.new do
            Sample.transaction(requires_new: false) do
              make_parent_transaction_dirty
              Sample.transaction(requires_new: true) do
                assert_current_transaction_is_savepoint_transaction
                s1.lock!
                barrier.wait
                s2.update value: 1
              end
            end
          end

          begin
            Sample.transaction(requires_new: false) do
              make_parent_transaction_dirty
              Sample.transaction(requires_new: true) do
                assert_current_transaction_is_savepoint_transaction
                s2.lock!
                barrier.wait
                s1.update value: 2
              end
            end
          ensure
            thread.join
          end
        rescue ActiveRecord::StatementInvalid => e
          if /SAVEPOINT active_record_. does not exist/ =~ e.to_s
            flunk "ROLLBACK TO SAVEPOINT query issued for savepoint that no longer exists due to deadlock: #{e}"
          else
            raise e
          end
        end
      end
      assert_predicate connection, :active?
    end

    test "deadlock inside nested SavepointTransaction is recoverable" do
      barrier = Concurrent::CyclicBarrier.new(2)
      deadlocks = 0

      s1 = Sample.create value: 1
      s2 = Sample.create value: 2

      thread = Thread.new do
        Sample.transaction(requires_new: false) do
          make_parent_transaction_dirty
          begin
            Sample.transaction(requires_new: true) do
              assert_current_transaction_is_savepoint_transaction
              s1.lock!
              barrier.wait
              s2.update value: 4
            end
          rescue ActiveRecord::Deadlocked
            deadlocks += 1
          end
          s2.update value: 10
        end
      end

      begin
        Sample.transaction(requires_new: false) do
          make_parent_transaction_dirty
          begin
            Sample.transaction(requires_new: true) do
              assert_current_transaction_is_savepoint_transaction
              s2.lock!
              barrier.wait
              s1.update value: 3
            end
          rescue ActiveRecord::Deadlocked
            deadlocks += 1
          end
          s1.update value: 10
        end
      ensure
        thread.join
      end
      assert_equal 1, deadlocks
      assert_equal [10, 10], Sample.pluck(:value)
    end

    private
      # This should cause the next nested transaction to be a savepoint transaction.
      def make_parent_transaction_dirty
        Sample.take
      end

      def assert_current_transaction_is_savepoint_transaction
        current_transaction = Sample.connection.current_transaction
        unless current_transaction.is_a?(ActiveRecord::ConnectionAdapters::SavepointTransaction)
          flunk("current transaction is not a savepoint transaction")
        end
      end
  end
end
