# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      attr_accessor :statements

      public :prepare_statement

      class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
        attr_accessor :counter
      end

      class DeallocateDuplicatePreparedStatementTestWithTransactions < ActiveRecord::PostgreSQLTestCase
        NOOP = "SELECT 1;"

        def setup
          @connection = ActiveRecord::Base.connection
        end

        def test_duplicate_prepared_statement
          first_key, second_key = generate_keys

          assert_equal first_key, second_key
        end

        private

          def generate_keys
            first_key = @connection.prepare_statement NOOP
            @connection.statements.counter = 0
            second_key = @connection.prepare_statement NOOP

            [first_key, second_key]
          end
      end

      class DeallocatePreparedStatementTestWithoutTransactions < DeallocateDuplicatePreparedStatementTestWithTransactions
        self.use_transactional_tests = false
      end
    end
  end
end
