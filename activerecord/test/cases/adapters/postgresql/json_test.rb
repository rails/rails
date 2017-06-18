require "cases/helper"
require "cases/json_shared_test_cases"

module PostgresqlJSONSharedTestCases
  include JSONSharedTestCases

  def setup
    super
    @connection.create_table("json_data_type") do |t|
      t.public_send column_type, "payload", default: {} # t.json 'payload', default: {}
      t.public_send column_type, "settings"             # t.json 'settings'
      t.public_send column_type, "objects", array: true # t.json 'objects', array: true
    end
  rescue ActiveRecord::StatementInvalid
    skip "do not test on PostgreSQL without #{column_type} type."
  end

  def test_default
    @connection.add_column "json_data_type", "permissions", column_type, default: { "users": "read", "posts": ["read", "write"] }
    klass.reset_column_information

    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, JsonDataType.column_defaults["permissions"])
    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, JsonDataType.new.permissions)
  end

  def test_deserialize_with_array
    x = klass.new(objects: ["foo" => "bar"])
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

  def test_keys_unsorted_when_fetched_from_DB
    jsonb = {"name" => "nakshay", "age" => '24'}
    x = JsonDataType.new payload: jsonb
    x.save
    x.reload
    assert_equal(['name', 'age'], x.payload.keys)
  end
end

class PostgresqlJSONBTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlJSONSharedTestCases

  def column_type
    :jsonb
  end

  def test_keys_of_same_length_sorted_when_fetched_from_DB
    jsonb = {"name" => "nakshay", "age" => '24'}
    x = JsonDataType.new payload: jsonb
    x.save
    x.reload
    assert_equal(['age', 'name'], x.payload.keys)
  end
end
