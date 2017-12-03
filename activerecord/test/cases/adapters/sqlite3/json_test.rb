# frozen_string_literal: true

require "cases/helper"
require "cases/json_shared_test_cases"

class SQLite3JSONTest < ActiveRecord::SQLite3TestCase
  include JSONSharedTestCases

  def setup
    super
    @connection.create_table("json_data_type") do |t|
      t.json "payload", default: {}
      t.json "settings"
    end
  end

  def test_default
    @connection.add_column "json_data_type", "permissions", column_type, default: { "users": "read", "posts": ["read", "write"] }
    klass.reset_column_information

    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, klass.column_defaults["permissions"])
    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, klass.new.permissions)
  end

  private
    def column_type
      :json
    end
end
