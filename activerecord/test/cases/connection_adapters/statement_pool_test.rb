# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class StatementPoolTest < ActiveRecord::TestCase
      class TestPool < StatementPool
        private
          def dealloc(stmt)
            raise ArgumentError unless stmt
          end
      end

      setup do
        @pool = TestPool.new
      end

      test "#delete doesn't call dealloc if the statement didn't exist" do
        stmt = Object.new
        sql = "SELECT 1"
        @pool[sql] = stmt
        assert_same stmt, @pool[sql]
        assert_same stmt, @pool.delete(sql)
        assert_nil @pool.delete(sql)
      end
    end
  end
end
