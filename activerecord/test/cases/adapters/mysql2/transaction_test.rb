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

    test "raises error when a serialization failure occurs" do
      assert_raises(ActiveRecord::TransactionSerializationError) do
        thread = Thread.new do
          Sample.transaction isolation: :serializable do
            Sample.delete_all

            10.times do |i|
              sleep 0.1

              Sample.create value: i
            end
          end
        end

        sleep 0.1

        Sample.transaction isolation: :serializable do
          Sample.delete_all

          10.times do |i|
            sleep 0.1

            Sample.create value: i
          end

          sleep 1
        end

        thread.join
      end
    end
  end
end
