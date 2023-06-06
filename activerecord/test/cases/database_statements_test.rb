# frozen_string_literal: true

require "cases/helper"
require "models/account"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  unless current_adapter?(:OracleAdapter)
    def test_exec_insert
      result = @connection.exec_insert("INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)", nil, [])
      assert_not_nil @connection.send(:last_inserted_id, result)
    end
  end

  def test_insert_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :insert)
  end

  def test_create_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :create)
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_exec_insert_returns_result_with_values_for_returning_columns
      sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
      result = @connection.exec_insert(sql, returning: ["firm_id", "credit_limit", "status"])
      returning_values = result.first.values_at("firm_id", "credit_limit")

      assert_equal([42, 5000], returning_values)
    end

    def test_insert_returns_values_for_returning_columns
      sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
      result = @connection.insert(sql, returning: ["firm_id", "credit_limit", "status"])

      assert_equal([42, 5000, nil], result)
    end
  else
    def test_exec_insert_raises_when_called_with_multiple_returning_when_not_supported
      sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
      expected_message = "Current adapter does not support returning determined columns from an insert statement"

      assert_raises ArgumentError, match: expected_message do
        @connection.exec_insert(sql, returning: ["firm_id", "credit_limit"])
      end
    end

    def test_insert_raises_when_called_with_multiple_returning_when_not_supported
      sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
      expected_message = "Current adapter does not support returning determined columns from an insert statement"

      assert_raises ArgumentError, match: expected_message do
        @connection.insert(sql, returning: ["firm_id", "credit_limit"])
      end
    end
  end

  def test_insert_with_nil_returning_returns_last_insert_id_column_value
    sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
    inserted_id = @connection.insert(sql, returning: nil)

    assert_not_nil(inserted_id)
    assert_equal(5000, Account.find(inserted_id).credit_limit)
  end

  def test_insert_with_empty_returning_returns_empty_array
    sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
    result = @connection.insert(sql, returning: [])
    assert_empty(result)
  end

  private
    def return_the_inserted_id(method:)
      # Oracle adapter uses prefetched primary key values from sequence and passes them to connection adapter insert method
      if current_adapter?(:OracleAdapter)
        sequence_name = "accounts_seq"
        id_value = @connection.next_sequence_value(sequence_name)
        @connection.send(method, "INSERT INTO accounts (id, firm_id,credit_limit) VALUES (accounts_seq.nextval,42,5000)", nil, :id, id_value, sequence_name)
      else
        @connection.send(method, "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
      end
    end
end
