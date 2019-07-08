# frozen_string_literal: true

require "cases/helper"

class PostgresqlIndexTest < ActiveRecord::PostgreSQLTestCase
  def setup
    super

    @connection = ActiveRecord::Base.connection

    @connection.create_table "table_name" do |t|
      t.column "foo", :string
    end

    @connection.create_schema "custom_schema"
    @connection.create_table "custom_schema.table_name" do |t|
      t.column "bar", :string
    end
  end

  teardown do
    @connection.drop_table("table_name")
    @connection.drop_schema("custom_schema")
  end

  def test_add_index_with_same_name_table_name_different_schemas
    index_name = "some_index_name"
    @connection.add_index("table_name", "foo", name: index_name)
    @connection.add_index("custom_schema.table_name", "bar", name: index_name)

    assert @connection.index_exists?("table_name", "foo", name: index_name)
    assert @connection.index_exists?("custom_schema.table_name", "bar", name: index_name)
  end
end
