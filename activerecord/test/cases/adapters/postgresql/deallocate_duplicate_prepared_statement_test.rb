# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      attr_accessor :statements

      public :prepare_statement

      class DeallocateDuplicatePreparedStatementTestWithTransactions < ActiveRecord::PostgreSQLTestCase
        NOOP_1 = "SELECT 1;"
        NOOP_2 = "SELECT 2;"

        def setup
          @connection = ActiveRecord::Base.connection
        end

        def test_duplicate_prepared_statement
          @connection.statements.stub :next_key, "a0" do
            first_key, second_key = generate_keys

            assert_equal first_key, second_key
          end
        end

        private

          def generate_keys
            first_key = @connection.prepare_statement NOOP_1
            second_key = @connection.prepare_statement NOOP_2

            [first_key, second_key]
          end
      end

      class DeallocatePreparedStatementTestWithoutTransactions < DeallocateDuplicatePreparedStatementTestWithTransactions
        self.use_transactional_tests = false
      end
    end
  end
end
