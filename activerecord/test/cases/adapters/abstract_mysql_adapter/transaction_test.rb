# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  class TransactionTest < ActiveRecord::AbstractMysqlTestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = "samples"
    end

    setup do
      @abort, Thread.abort_on_exception = Thread.abort_on_exception, false
      Thread.report_on_exception, @original_report_on_exception = false, Thread.report_on_exception

      connection = ActiveRecord::Base.lease_connection
      connection.clear_cache!

      connection.transaction do
        connection.drop_table "samples", if_exists: true
        connection.create_table("samples") do |t|
          t.integer "value"
        end
      end

      Sample.reset_column_information
    end

    teardown do
      ActiveRecord::Base.lease_connection.drop_table "samples", if_exists: true

      Thread.abort_on_exception = @abort
      Thread.report_on_exception = @original_report_on_exception
    end

    test "raises Deadlocked when a deadlock is encountered" do
      connection = Sample.lease_connection
      assert_raises(ActiveRecord::Deadlocked) do
        barrier = Concurrent::CyclicBarrier.new(2)

        s1 = Sample.create value: 1
        s2 = Sample.create value: 2

        thread = Thread.new do
          Sample.transaction do
            s1.lock!
            barrier.wait
            s2.update value: 1
          end
        end

        begin
          Sample.transaction do
            s2.lock!
            barrier.wait
            s1.update value: 2
          end
        ensure
          thread.join
        end
      end
      assert_predicate connection, :active?
    end

    test "raises LockWaitTimeout when lock wait timeout exceeded" do
      assert_raises(ActiveRecord::LockWaitTimeout) do
        s = Sample.create!(value: 1)
        latch1 = Concurrent::CountDownLatch.new
        latch2 = Concurrent::CountDownLatch.new

        thread = Thread.new do
          Sample.transaction do
            Sample.lock.find(s.id)
            latch1.count_down
            latch2.wait
          end
        end

        begin
          Sample.transaction do
            latch1.wait
            Sample.lease_connection.execute("SET innodb_lock_wait_timeout = 1")
            Sample.lock.find(s.id)
          end
        ensure
          Sample.lease_connection.execute("SET innodb_lock_wait_timeout = DEFAULT")
          latch2.count_down
          thread.join
        end
      end
    end

    test "raises StatementTimeout when statement timeout exceeded" do
      skip unless ActiveRecord::Base.lease_connection.show_variable("max_execution_time")
      error = assert_raises(ActiveRecord::StatementTimeout) do
        s = Sample.create!(value: 1)
        latch1 = Concurrent::CountDownLatch.new
        latch2 = Concurrent::CountDownLatch.new

        thread = Thread.new do
          Sample.transaction do
            Sample.lock.find(s.id)
            latch1.count_down
            latch2.wait
          end
        end

        begin
          Sample.transaction do
            latch1.wait
            Sample.lease_connection.execute("SET max_execution_time = 1")
            Sample.lock.find(s.id)
          end
        ensure
          Sample.lease_connection.execute("SET max_execution_time = DEFAULT")
          latch2.count_down
          thread.join
        end
      end
      assert_kind_of ActiveRecord::QueryAborted, error
    end

    test "raises QueryCanceled when canceling statement due to user request" do
      error = assert_raises(ActiveRecord::QueryCanceled) do
        s = Sample.create!(value: 1)
        latch = Concurrent::CountDownLatch.new

        thread = Thread.new do
          Sample.transaction do
            Sample.lock.find(s.id)
            latch.count_down
            sleep(0.5)
            conn = Sample.lease_connection
            pid = conn.query_value("SELECT id FROM information_schema.processlist WHERE info LIKE '% FOR UPDATE'")
            conn.execute("KILL QUERY #{pid}")
          end
        end

        begin
          Sample.transaction do
            latch.wait
            Sample.lock.find(s.id)
          end
        ensure
          thread.join
        end
      end
      assert_kind_of ActiveRecord::QueryAborted, error
    end

    test "reconnect preserves isolation level" do
      pool = Sample.connection_pool
      @connection = Sample.lease_connection

      Sample.transaction do
        @connection.materialize_transactions
        # Double check that the INSERT isn't seen with default isolation level
        assert_no_difference -> { Sample.count } do
          Thread.new do
            Sample.create!(value: 1)
          end.join
        end
      end

      Sample.transaction(isolation: :read_committed) do
        @connection.materialize_transactions
        # Double check that the INSERT is seen with :read_committed
        assert_difference -> { Sample.count }, +1 do
          Thread.new do
            Sample.create!(value: 1)
          end.join
        end
      end

      first_begin_failed = false
      @connection.singleton_class.define_method(:perform_query) do |raw_connection, sql, *args, **kwargs|
        # Simulates the first BEGIN attempt failing
        if sql.include?("BEGIN") && !first_begin_failed
          first_begin_failed = true
          raise ActiveRecord::ConnectionFailed, "Simulated failure"
        end
        super(raw_connection, sql, *args, **kwargs)
      end

      Sample.transaction(isolation: :read_committed) do
        @connection.materialize_transactions
        # Indirectly check that the retried transaction is READ COMMITTED
        assert_difference -> { Sample.count }, +1 do
          Thread.new do
            Sample.create!(value: 1)
          end.join
        end
      end

      assert first_begin_failed
    ensure
      pool.remove(@connection) # We're monkey patching the instance, we shouldn't re-use it
      @connection&.disconnect!
      Sample.release_connection
    end
  end
end
