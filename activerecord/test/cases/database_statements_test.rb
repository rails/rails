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

  def test_extract_table_ref_from_insert_sql_with_quoting
    [
      "table-name",
      "table with space",
      "a" * 120, # long name
      "таблица",
      "日本語テーブル",
      "clientes_ñ",
      "select",
      "table""with""quotes",
      "table/with\\special",
    ].each do |valid_table_name|
      sql = "INSERT INTO \"#{valid_table_name}\" (column1, column2) VALUES (value1, value2)"

      assert_equal valid_table_name, @connection.send(:extract_table_ref_from_insert_sql, sql)
    end
  end

  def test_extract_table_ref_from_insert_sql_without_quoting
    [
      "table_name",
      "[dbo].[users]",
      "[users]",
      "[My Table]",
      "[dbo].[My Table]",
      "[catalog].[schema].[table]",
      "[test-table]",
      "[select]",
      "[таблица]",
      "[table[with]]brackets]",
      "[dbo].[test-table with spaces]",
      "[dbo].[bracket]]name]",
      "dbo.users",
      "catalog.schema.table",
      "schema1.table123",
      '"public"."table"'
    ].each do |valid_table_name|
      sql = "INSERT INTO #{valid_table_name} (column1, column2) VALUES (value1, value2)"

      assert_equal valid_table_name, @connection.send(:extract_table_ref_from_insert_sql, sql)
    end
  end

  private
    def return_the_inserted_id(method:)
      @connection.send(method, "INSERT INTO accounts (firm_id,credit_limit) VALUES (42,5000)")
    end
end
