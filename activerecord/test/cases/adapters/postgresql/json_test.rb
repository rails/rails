# frozen_string_literal: true

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

    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, klass.column_defaults["permissions"])
    assert_equal({ "users" => "read", "posts" => ["read", "write"] }, klass.new.permissions)
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

  # PostgreSQL's `json` type differs from `jsonb`
  # you cannot select by a single numeric value w/o explicit casts for raw sql params
  # but since PostgreSQL's `json` is in fact just `text` casts are ok
  def test_select_by_integer_value
    json = klass.create!(payload: 42)
    x = klass.where("payload::text = ?::text", 42).first
    assert_equal(json, x)
  end

  def test_select_by_float_value
    json = klass.create!(payload: 1.234)
    x = klass.where("payload::text = ?::text", 1.234).first
    assert_equal(json, x)
  end

  def test_select_by_integer_value_without_cast
    error = assert_raises(ActiveRecord::StatementInvalid) do
      klass.where(payload: 42).first
    end

    assert_match(
      %r/operator does not exist: json = unknown/,
      error.message
    )

    assert_match(
      %r/WHERE "json_data_type"\."payload" = \$1 ORDER/,
      error.message
    )

    assert_not_nil error.cause
  ensure
    @connection.reconnect! if @connection.raw_connection.transaction_status == 3 # PG::PQTRANS_INERROR
  end

  def test_select_by_float_value_without_cast
    error = assert_raises(ActiveRecord::StatementInvalid) do
      klass.where(payload: 1.234).first
    end

    assert_match(
      %r/operator does not exist: json = unknown/,
      error.message
    )

    assert_match(
      %r/WHERE "json_data_type"\."payload" = \$1 ORDER/,
      error.message
    )

    assert_not_nil error.cause
  ensure
    @connection.reconnect! if @connection.raw_connection.transaction_status == 3 # PG::PQTRANS_INERROR
  end
end

class PostgresqlJSONBTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlJSONSharedTestCases

  def column_type
    :jsonb
  end
end
