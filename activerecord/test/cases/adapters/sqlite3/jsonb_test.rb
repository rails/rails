# frozen_string_literal: true

require "cases/helper"
require "cases/json_shared_test_cases"

class SQLite3JSONBTest < ActiveRecord::SQLite3TestCase
  include JSONSharedTestCases

  def setup
    super
    @connection.create_table("json_data_type") do |t|
      t.jsonb "payload", default: {}
      t.jsonb "with_defaults", default: { list: [] }
      t.jsonb "settings"
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

  private
    def column_type
      # sqlite3 does not support jsonb; the adapter uses json type for both json and jsonb
      :json
    end
end
