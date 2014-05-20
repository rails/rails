# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlJSONBTest < ActiveRecord::TestCase
  class JsonbDataType < ActiveRecord::Base
    self.table_name = 'jsonb_data_type'

    store_accessor :settings, :resolution
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('jsonb_data_type') do |t|
          t.jsonb 'payload', :default => {}
          t.jsonb 'settings'
        end
      end
    rescue ActiveRecord::StatementInvalid
      skip "do not test on PG without jsonb"
    end
    @column = JsonbDataType.columns_hash['payload']
  end

  teardown do
    @connection.execute 'drop table if exists jsonb_data_type'
  end

  def test_column
    column = JsonbDataType.columns_hash["payload"]
    assert_equal :jsonb, column.type
    assert_equal "jsonb", column.sql_type
    assert_not column.number?
    assert_not column.text?
    assert_not column.binary?
    assert_not column.array
  end

  def test_default
    @connection.add_column 'jsonb_data_type', 'permissions', :jsonb, default: '{"users": "read", "posts": ["read", "write"]}'
    JsonbDataType.reset_column_information
    column = JsonbDataType.columns_hash["permissions"]

    assert_equal({"users"=>"read", "posts"=>["read", "write"]}, column.default)
    assert_equal({"users"=>"read", "posts"=>["read", "write"]}, JsonbDataType.new.permissions)
  ensure
    JsonbDataType.reset_column_information
  end

  def test_change_table_supports_jsonb
    @connection.transaction do
      @connection.change_table('jsonb_data_type') do |t|
        t.jsonb 'users', default: '{}'
      end
      JsonbDataType.reset_column_information
      column = JsonbDataType.columns_hash['users']
      assert_equal :jsonb, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    JsonbDataType.reset_column_information
  end

  def test_cast_value_on_write
    x = JsonbDataType.new payload: {"string" => "foo", :symbol => :bar}
    assert_equal({"string" => "foo", "symbol" => "bar"}, x.payload)
    x.save
    assert_equal({"string" => "foo", "symbol" => "bar"}, x.reload.payload)
  end

  def test_type_cast_jsonb
    column = JsonbDataType.columns_hash["payload"]

    data = "{\"a_key\":\"a_value\"}"
    hash = column.class.string_to_json data
    assert_equal({'a_key' => 'a_value'}, hash)
    assert_equal({'a_key' => 'a_value'}, column.type_cast(data))

    assert_equal({}, column.type_cast("{}"))
    assert_equal({'key'=>nil}, column.type_cast('{"key": null}'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, column.type_cast(%q({"c":"}", "\"a\"":"b \"a b"})))
  end

  def test_rewrite
    @connection.execute "insert into jsonb_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonbDataType.first
    x.payload = { '"a\'' => 'b' }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into jsonb_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonbDataType.first
    assert_equal({'k' => 'v'}, x.payload)
  end

  def test_select_multikey
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES ('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}')|
    x = JsonbDataType.first
    assert_equal({'k1' => 'v1', 'k2' => 'v2', 'k3' => [1,2,3]}, x.payload)
  end

  def test_null_jsonb
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES(null)|
    x = JsonbDataType.first
    assert_equal(nil, x.payload)
  end

  def test_select_array_jsonb_value
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonbDataType.first
    assert_equal(['v0', {'k1' => 'v1'}], x.payload)
  end

  def test_rewrite_array_jsonb_value
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonbDataType.first
    x.payload = ['v1', {'k2' => 'v2'}, 'v3']
    assert x.save!
  end

  def test_with_store_accessors
    x = JsonbDataType.new(resolution: "320×480")
    assert_equal "320×480", x.resolution

    x.save!
    x = JsonbDataType.first
    assert_equal "320×480", x.resolution

    x.resolution = "640×1136"
    x.save!

    x = JsonbDataType.first
    assert_equal "640×1136", x.resolution
  end

  def test_update_all
    jsonb = JsonbDataType.create! payload: { "one" => "two" }

    JsonbDataType.update_all payload: { "three" => "four" }
    assert_equal({ "three" => "four" }, jsonb.reload.payload)

    JsonbDataType.update_all payload: { }
    assert_equal({ }, jsonb.reload.payload)
  end
end
