# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
        attr_accessor :counter
      end

      class DeallocateDuplicatePreparedStatementTestWithTransactions < ActiveRecord::PostgreSQLTestCase
        NOOP = "SELECT 1;"

        def setup
          @connection = ActiveRecord::Base.connection.raw_connection
          @statement_pool = StatementPool.new(@connection, 10)
        end

        def test_duplicate_prepared_statement
          first_key, second_key = generate_keys

          assert_equal first_key, second_key
        end

        private

          def generate_keys
            first_key = @statement_pool.next_key
            @connection.prepare first_key, NOOP

            @statement_pool.counter = 0

            second_key = @statement_pool.next_key
            @connection.prepare second_key, NOOP

            [first_key, second_key]
          end
      end

      class DeallocatePreparedStatementTestWithoutTransactions < DeallocateDuplicatePreparedStatementTestWithTransactions
        self.use_transactional_tests = false
      end
    end
  end
end
