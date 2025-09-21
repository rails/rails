# frozen_string_literal: true

require "cases/helper"
require "cases/json_shared_test_cases"

class SQLite3JSONTest < ActiveRecord::SQLite3TestCase
  include JSONSharedTestCases

  def setup
    super
    @connection.create_table("json_data_type") do |t|
      t.json "payload", default: {}
      t.json "with_defaults", default: { list: [] }
      t.json "settings"
    end
  end

  def test_default
    @connection.add_column "json_data_type", "permissions", column_type, default: { "users": "read", "posts": ["read", "write"] }
    klass.reset_column_information

    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, klass.column_defaults["permissions"])
    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, klass.new.permissions)
  end

  def test_default_before_type_cast
    assert_equal '{"list":[]}', klass.new.with_defaults_before_type_cast
  end

  def test_invalid_json_can_be_updated
    model = klass.create!
    @connection.execute("UPDATE #{klass.table_name} SET payload = '---'")

    model.reload
    assert_equal "---", model.payload_before_type_cast
    assert_error_reported(JSON::ParserError) do
      assert_nil model.payload
    end

    model.update(payload: "no longer invalid")
    assert_equal("no longer invalid", model.payload)
  end

  private
    def column_type
      :json
    end
end
