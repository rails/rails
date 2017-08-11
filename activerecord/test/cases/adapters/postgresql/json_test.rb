require "cases/helper"
require "cases/json_shared_test_cases"

module PostgresqlJSONSharedTestCases
  include JSONSharedTestCases

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.create_table("json_data_type") do |t|
        t.public_send column_type, "payload", default: {} # t.json 'payload', default: {}
        t.public_send column_type, "settings"             # t.json 'settings'
        t.public_send column_type, "objects", array: true # t.json 'objects', array: true
      end
    rescue ActiveRecord::StatementInvalid
      skip "do not test on PostgreSQL without #{column_type} type."
    end
  end

  def teardown
    @connection.drop_table :json_data_type, if_exists: true
    JsonDataType.reset_column_information
  end

  def test_default
    @connection.add_column "json_data_type", "permissions", column_type, default: { "users": "read", "posts": ["read", "write"] }
    JsonDataType.reset_column_information

    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, JsonDataType.column_defaults["permissions"])
    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, JsonDataType.new.permissions)
  ensure
    JsonDataType.reset_column_information
  end

  def test_deserialize_with_array
    x = JsonDataType.new(objects: ["foo" => "bar"])
    assert_equal ["foo" => "bar"], x.objects
    x.save!
    assert_equal ["foo" => "bar"], x.objects
    x.reload
    assert_equal ["foo" => "bar"], x.objects
  end
end

class PostgresqlJSONTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlJSONSharedTestCases

  def column_type
    :json
  end
end

class PostgresqlJSONBTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlJSONSharedTestCases

  def column_type
    :jsonb
  end
end
