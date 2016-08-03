require "cases/helper"
require 'support/connection_helper'

module ActiveRecord
  class Mysql2TransactionTest < ActiveRecord::Mysql2TestCase
    self.use_transactional_tests = false

    class Sample < ActiveRecord::Base
      self.table_name = 'samples'
    end

    setup do
      @connection = ActiveRecord::Base.connection
      @connection.clear_cache!

      @connection.transaction do
        @connection.drop_table 'samples', if_exists: true
        @connection.create_table('samples') do |t|
          t.integer 'value'
        end
      end

      Sample.reset_column_information
    end

    teardown do
      @connection.drop_table 'samples', if_exists: true
    end

    test "raises DeadlockDetected when a deadlock is encountered" do
      assert_raises(ActiveRecord::DeadlockDetected) do
        s1 = Sample.create value: 1
        s2 = Sample.create value: 2

        thread = Thread.new do
          Sample.transaction do
            s1.lock!
            sleep 1
            s2.update_attributes value: 1
          end
        end

        sleep 0.5

        Sample.transaction do
          s2.lock!
          sleep 1
          s1.update_attributes value: 2
        end

        thread.join
      end
    end
  end
end
