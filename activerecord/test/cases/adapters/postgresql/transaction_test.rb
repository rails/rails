# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "concurrent/atomic/cyclic_barrier"

module ActiveRecord
  class PostgresqlTransactionTest < ActiveRecord::PostgreSQLTestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = "samples"
    end

    setup do
      @abort, Thread.abort_on_exception = Thread.abort_on_exception, false
      Thread.report_on_exception, @original_report_on_exception = false, Thread.report_on_exception

      connection = ActiveRecord::Base.lease_connection

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

    test "raises SerializationFailure when a serialization failure occurs" do
      assert_raises(ActiveRecord::SerializationFailure) do
        before = Concurrent::CyclicBarrier.new(2)
        after = Concurrent::CyclicBarrier.new(2)

        thread = Thread.new do
          Sample.transaction isolation: :serializable do
            before.wait
            Sample.create value: Sample.sum(:value)
            after.wait
          end
        end

        begin
          Sample.transaction isolation: :serializable do
            before.wait
            Sample.create value: Sample.sum(:value)
            after.wait
          end
        ensure
          thread.join
        end
      end
    end

    test "raises Deadlocked when a deadlock is encountered" do
      connections = Concurrent::Set.new
      assert_raises(ActiveRecord::Deadlocked) do
        barrier = Concurrent::CyclicBarrier.new(2)

        s1 = Sample.create value: 1
        s2 = Sample.create value: 2

        thread = Thread.new do
          connections.add Sample.lease_connection
          Sample.transaction do
            s1.lock!
            barrier.wait
            s2.update value: 1
          end
        end

        begin
          connections.add Sample.lease_connection
          Sample.transaction do
            s2.lock!
            barrier.wait
            s1.update value: 2
          end
        ensure
          thread.join
        end
      end
      assert connections.all?(&:active?)
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
            Sample.lease_connection.execute("SET lock_timeout = 1")
            Sample.lock.find(s.id)
          end
        ensure
          Sample.lease_connection.execute("SET lock_timeout = DEFAULT")
          latch2.count_down
          thread.join
        end
      end
    end

    test "raises QueryCanceled when statement timeout exceeded" do
      assert_raises(ActiveRecord::QueryCanceled) do
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
            Sample.lease_connection.execute("SET statement_timeout = 1")
            Sample.lock.find(s.id)
          end
        ensure
          Sample.lease_connection.execute("SET statement_timeout = DEFAULT")
          latch2.count_down
          thread.join
        end
      end
    end

    test "raises QueryCanceled when canceling statement due to user request" do
      assert_raises(ActiveRecord::QueryCanceled) do
        s = Sample.create!(value: 1)
        latch = Concurrent::CountDownLatch.new

        thread = Thread.new do
          Sample.transaction do
            Sample.lock.find(s.id)
            latch.count_down
            sleep(0.5)
            conn = Sample.lease_connection
            pid = conn.select_value("SELECT pid FROM pg_stat_activity WHERE query LIKE '% FOR UPDATE'")
            conn.execute("SELECT pg_cancel_backend(#{pid})")
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
    end

    test "raises Interrupt when canceling statement via interrupt" do
      if PG.library_version >= 18_00_00 && Gem::Version.new(PG::VERSION) < Gem::Version.new("1.6.0")
        skip "PG::Connection#cancel should not run when libpq of PostgreSQL #{PG.library_version / 10000} with pg gem version #{PG::VERSION}"
      end
      start_time = Time.now
      thread = Thread.new do
        Sample.transaction do
          Sample.lease_connection.execute("SELECT pg_sleep(10)")
        end
      rescue Exception => e
        e
      end

      sleep(0.5)
      thread.raise Interrupt
      thread.join
      duration = Time.now - start_time

      assert_instance_of Interrupt, thread.value
      assert_operator duration, :<, 5
    end
  end
end
