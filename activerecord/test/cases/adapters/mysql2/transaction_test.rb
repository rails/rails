# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

module ActiveRecord
  class Mysql2TransactionTest < ActiveRecord::Mysql2TestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = "samples"
    end

    setup do
      @abort, Thread.abort_on_exception = Thread.abort_on_exception, false

      @connection = ActiveRecord::Base.connection
      @connection.clear_cache!

      @connection.transaction do
        @connection.drop_table "samples", if_exists: true
        @connection.create_table("samples") do |t|
          t.integer "value"
        end
      end

      Sample.reset_column_information
    end

    teardown do
      @connection.drop_table "samples", if_exists: true

      Thread.abort_on_exception = @abort
    end

    test "raises Deadlocked when a deadlock is encountered" do
      assert_raises(ActiveRecord::Deadlocked) do
        barrier = Concurrent::CyclicBarrier.new(2)

        s1 = Sample.create value: 1
        s2 = Sample.create value: 2

        thread = Thread.new do
          Sample.transaction do
            s1.lock!
            barrier.wait
            s2.update_attributes value: 1
          end
        end

        begin
          Sample.transaction do
            s2.lock!
            barrier.wait
            s1.update_attributes value: 2
          end
        ensure
          thread.join
        end
      end
    end

    test "raises TransactionTimeout when lock wait timeout exceeded" do
      assert_raises(ActiveRecord::TransactionTimeout) do
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
            Sample.connection.execute("SET innodb_lock_wait_timeout = 1")
            Sample.lock.find(s.id)
          end
        ensure
          Sample.connection.execute("SET innodb_lock_wait_timeout = DEFAULT")
          latch2.count_down
          thread.join
        end
      end
    end
  end
end
