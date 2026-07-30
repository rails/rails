# frozen_string_literal: true

require "cases/helper"

class DatabaseStatementsTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def test_exec_insert
    result = assert_deprecated(ActiveRecord.deprecator) do
      @connection.exec_insert("INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)", nil, [])
    end
    assert_not_nil @connection.send(:last_inserted_id, result)
  end

  def test_insert_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :insert)
  end

  def test_create_should_return_the_inserted_id
    assert_not_nil return_the_inserted_id(method: :create)
  end

  def test_insert_with_scalar_returning_returns_scalar
    sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
    id = @connection.insert(sql, returning: "id")
    assert_kind_of Integer, id
  end

  def test_insert_with_array_returning_returns_array
    sql = "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)"
    values = @connection.insert(sql, returning: ["id"])
    assert_kind_of Array, values
    assert_equal 1, values.length
  end

  def test_extract_table_ref_from_insert_sql_with_hyphen_in_table_name
    sql = "INSERT INTO \"table-with-hyphen\" (column1, column2) VALUES (value1, value2)"
    assert_equal "table-with-hyphen", @connection.send(:extract_table_ref_from_insert_sql, sql)
  end

  def test_to_sql_binds_arg_is_deprecated
    sql = "SELECT 1"
    assert_deprecated(/Passing `binds` to `to_sql`/, ActiveRecord.deprecator) do
      assert_equal sql, @connection.to_sql(sql, [])
    end
  end

  private
    def return_the_inserted_id(method:)
      @connection.send(method, "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
    end
end
