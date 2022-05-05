# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "concurrent/atomic/cyclic_barrier"

module ActiveRecord
  class PostgresqlTransactionNestedTest < ActiveRecord::PostgreSQLTestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = "samples"
    end
    class Bit < ActiveRecord::Base
      self.table_name = "bits"
    end

    setup do
      @abort, Thread.abort_on_exception = Thread.abort_on_exception, false
      Thread.report_on_exception, @original_report_on_exception = false, Thread.report_on_exception

      connection = ActiveRecord::Base.connection

      connection.transaction do
        connection.drop_table "samples", if_exists: true
        connection.drop_table "bits", if_exists: true
        connection.create_table("samples") do |t|
          t.integer "value"
        end
        connection.create_table("bits") do |t|
          t.integer "value"
        end
      end

      Sample.reset_column_information
      Bit.reset_column_information
    end

    teardown do
      ActiveRecord::Base.connection.drop_table "samples", if_exists: true
      ActiveRecord::Base.connection.drop_table "bits", if_exists: true

      Thread.abort_on_exception = @abort
      Thread.report_on_exception = @original_report_on_exception
    end

    test "unserializable transaction raises SerializationFailure inside nested SavepointTransaction" do
      assert_raises(ActiveRecord::SerializationFailure) do
        before = Concurrent::CyclicBarrier.new(2)
        after = Concurrent::CyclicBarrier.new(2)

        thread = Thread.new do
          with_warning_suppression do
            Sample.transaction(isolation: :serializable, requires_new: false) do
              make_parent_transaction_dirty
              Sample.transaction(requires_new: true) do
                assert_current_transaction_is_savepoint_transaction
                before.wait
                Sample.create value: Sample.sum(:value)
                after.wait
              end
            end
          end
        end

        begin
          with_warning_suppression do
            Sample.transaction(isolation: :serializable, requires_new: false) do
              make_parent_transaction_dirty
              Sample.transaction(requires_new: true) do
                assert_current_transaction_is_savepoint_transaction
                before.wait
                Sample.create value: Sample.sum(:value)
                after.wait
              end
            end
          end
        ensure
          thread.join
        end
      end
    end

    test "SerializationFailure inside nested SavepointTransaction is recoverable" do
      start_right = Concurrent::Event.new
      commit_left = Concurrent::Event.new
      finish_right = Concurrent::Event.new
      Sample.create value: 1

      thread = Thread.new do
        with_warning_suppression do
          Sample.transaction(isolation: :serializable, requires_new: false) do
            Sample.update_all value: 2
            start_right.set
            commit_left.wait(1)
          end
          finish_right.set
        end
      end

      begin
        with_warning_suppression do
          start_right.wait
          Sample.transaction(isolation: :serializable, requires_new: false) do
            make_parent_transaction_dirty
            assert_raises(ActiveRecord::SerializationFailure) do
              Sample.transaction(requires_new: true) do
                assert_current_transaction_is_savepoint_transaction
                Sample.create value: 3
                commit_left.set
                finish_right.wait(2)
                Sample.update_all value: 4
              end
            end
            Bit.create value: 1
          end
        end
      ensure
        thread.join
      end
      assert_equal [2], Sample.pluck(:value)
      assert_equal [1], Bit.pluck(:value)
    end

    test "deadlock raises Deadlocked inside nested SavepointTransaction" do
      with_warning_suppression do
        connections = Concurrent::Set.new
        assert_raises(ActiveRecord::Deadlocked) do
          barrier = Concurrent::CyclicBarrier.new(2)

          s1 = Sample.create value: 1
          s2 = Sample.create value: 2

          thread = Thread.new do
            connections.add Sample.connection
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
            connections.add Sample.connection
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
        end
        assert connections.all?(&:active?)
      end
    end

    test "deadlock inside nested SavepointTransaction is recoverable" do
      with_warning_suppression do
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
    end

    private
      def with_warning_suppression
        log_level = ActiveRecord::Base.connection.client_min_messages
        ActiveRecord::Base.connection.client_min_messages = "error"
        yield
      ensure
        ActiveRecord::Base.clear_active_connections!
        ActiveRecord::Base.connection.client_min_messages = log_level
      end

      # These tests are coordinating a controlled sequence of accesses to rows in `samples` table under serializable isolation.
      # We need to run a query to dirty our transaction, but must avoid touching `samples` rows
      # because otherwise our no-op query becomes an active participant of the test setup
      def make_parent_transaction_dirty
        Bit.take
      end

      def assert_current_transaction_is_savepoint_transaction
        current_transaction = Sample.connection.current_transaction
        unless current_transaction.is_a?(ActiveRecord::ConnectionAdapters::SavepointTransaction)
          flunk("current transaction is not a savepoint transaction")
        end
      end
  end
end
