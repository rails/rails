# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlJSONTest < ActiveRecord::TestCase
  class JsonDataType < ActiveRecord::Base
    self.table_name = 'json_data_type'

    store_accessor :settings, :resolution
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('json_data_type') do |t|
          t.json 'payload', :default => {}
          t.json 'settings'
          t.json 'jsonarr', array: true
        end
      end
    rescue ActiveRecord::StatementInvalid
      skip "do not test on PG without json"
    end
    @column = JsonDataType.columns.find { |c| c.name == 'payload' }
  end

  teardown do
    @connection.execute 'drop table if exists json_data_type'
  end

  def test_column
    column = JsonDataType.columns_hash["payload"]
    assert_equal :json, column.type
    assert_equal "json", column.sql_type
    assert_not column.number?
    assert_not column.text?
    assert_not column.binary?
    assert_not column.array
  end

  def test_default
    @connection.add_column 'json_data_type', 'permissions', :json, default: '{"users": "read", "posts": ["read", "write"]}'
    JsonDataType.reset_column_information
    column = JsonDataType.columns_hash["permissions"]

    assert_equal({"users"=>"read", "posts"=>["read", "write"]}, column.default)
    assert_equal({"users"=>"read", "posts"=>["read", "write"]}, JsonDataType.new.permissions)
  ensure
    JsonDataType.reset_column_information
  end

  def test_change_table_supports_json
    @connection.transaction do
      @connection.change_table('json_data_type') do |t|
        t.json 'users', default: '{}'
      end
      JsonDataType.reset_column_information
      column = JsonDataType.columns.find { |c| c.name == 'users' }
      assert_equal :json, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    JsonDataType.reset_column_information
  end

  def test_cast_value_on_write
    x = JsonDataType.new payload: {"string" => "foo", :symbol => :bar}
    assert_equal({"string" => "foo", "symbol" => "bar"}, x.payload)
    x.save
    assert_equal({"string" => "foo", "symbol" => "bar"}, x.reload.payload)
  end

  def test_type_cast_json
    column = JsonDataType.columns_hash["payload"]

    data = "{\"a_key\":\"a_value\"}"
    hash = column.class.string_to_json data
    assert_equal({'a_key' => 'a_value'}, hash)
    assert_equal({'a_key' => 'a_value'}, column.type_cast(data))

    assert_equal({}, column.type_cast("{}"))
    assert_equal({'key'=>nil}, column.type_cast('{"key": null}'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, column.type_cast(%q({"c":"}", "\"a\"":"b \"a b"})))
  end

  def test_rewrite
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonDataType.first
    x.payload = { '"a\'' => 'b' }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonDataType.first
    assert_equal({'k' => 'v'}, x.payload)
  end

  def test_select_multikey
    @connection.execute %q|insert into json_data_type (payload) VALUES ('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}')|
    x = JsonDataType.first
    assert_equal({'k1' => 'v1', 'k2' => 'v2', 'k3' => [1,2,3]}, x.payload)
  end

  def test_null_json
    @connection.execute %q|insert into json_data_type (payload) VALUES(null)|
    x = JsonDataType.first
    assert_equal(nil, x.payload)
  end

  def test_select_array_json_value
    @connection.execute %q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonDataType.first
    assert_equal(['v0', {'k1' => 'v1'}], x.payload)
  end

  def test_rewrite_array_json_value
    @connection.execute %q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonDataType.first
    x.payload = ['v1', {'k2' => 'v2'}, 'v3']
    assert x.save!
  end

  def test_with_store_accessors
    x = JsonDataType.new(resolution: "320×480")
    assert_equal "320×480", x.resolution

    x.save!
    x = JsonDataType.first
    assert_equal "320×480", x.resolution

    x.resolution = "640×1136"
    x.save!

    x = JsonDataType.first
    assert_equal "640×1136", x.resolution
  end

  def test_update_all
    json = JsonDataType.create! payload: { "one" => "two" }

    JsonDataType.update_all payload: { "three" => "four" }
    assert_equal({ "three" => "four" }, json.reload.payload)

    JsonDataType.update_all payload: { }
    assert_equal({ }, json.reload.payload)
  end

  def test_update_all_json_array
    json = JsonDataType.create! payload: { "one" => "two" }

    JsonDataType.update_all jsonarr: ['{"type":"visitor", "value": 1}','{"type":"hit", "value": 2}']
    assert_equal([{"type"=>"visitor", "value"=>1}, {"type"=>"hit", "value"=>2}], json.reload.jsonarr)

    JsonDataType.update_all jsonarr: [{'test1'=>'1','test2'=>'2'}]
    assert_equal([{"test1"=>"1", "test2"=>"2"}], json.reload.jsonarr)    

    JsonDataType.update_all jsonarr: [[1,2],nil,nil]
    assert_equal([[1,2],nil,nil], json.reload.jsonarr)    
  end

  def test_default_json_array
    @connection.add_column 'json_data_type', 'test', :json, array:true, default: []
    JsonDataType.reset_column_information
    json = JsonDataType.create! payload: { "one" => "two" } 
    assert_equal([], json.reload.test)
  end

  def test_default_json_array2
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: ['{"type":"visitor", "value": 1}','{"type":"hit", "value": 2}']
    JsonDataType.reset_column_information
    json = JsonDataType.create! payload: { "one" => "two" } 
    assert_equal([{"type"=>"visitor", "value"=>1}, {"type"=>"hit", "value"=>2}], json.reload.test)
  end

  def test_default_json_array_with_null_string
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: ['{"type":"visitor", "value": 1}','["NULL"]']
    JsonDataType.reset_column_information
    json = JsonDataType.create! payload: { "one" => "two" } 
    assert_equal([{"type"=>"visitor", "value"=>1}, ["NULL"]], json.reload.test)
  end

  def test_default_json_array_in_array
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: [['{"type":"visitor", "value": 1}','{"type":"hit", "value": 2}'],['{"type":"visitor", "value": 2}','{"type":"hit", "value": 3}']]
    JsonDataType.reset_column_information
    json = JsonDataType.create! payload: { "one" => "two" } 
    assert_equal([['{"type":"visitor", "value": 1}','{"type":"hit", "value": 2}'],['{"type":"visitor", "value": 2}','{"type":"hit", "value": 3}']], json.reload.test)
  end

  def test_default_json_with_hash
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: [{'test1'=>'1','test2'=>'2'}]
    JsonDataType.reset_column_information
    json = JsonDataType.create! payload: { "one" => "two" } 
    assert_equal([{"test1"=>"1", "test2"=>"2"}], json.reload.test)
  end

  def test_default_json_array_with_hash
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: [{'test1'=>'1','test2'=>'2'},{'test3'=>'3'}]
    JsonDataType.reset_column_information
    json = JsonDataType.create! payload: { "one" => "two" } 
    assert_equal([{"test1"=>"1", "test2"=>"2"}, {"test3"=>"3"}], json.reload.test)
  end

  def test_default_json_with_rubyarray
    @connection.add_column 'json_data_type', 'test',:json, array:true, default: [1,2]
    JsonDataType.reset_column_information
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    json = JsonDataType.first
    assert_equal([1, 2],json.test) 
  end

  def test_default_json_array_with_rubyarray
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: [[1,2],[3,4]]
    JsonDataType.reset_column_information
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    json = JsonDataType.first
    assert_equal([[1,2],[3,4]],json.test)
  end

  def test_default_json_array_with_rubyarray_with_nil
    @connection.add_column 'json_data_type', 'test',:json,array:true, default: [[1,2],nil,nil]
    JsonDataType.reset_column_information
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    json = JsonDataType.first
    assert_equal([[1, 2], nil, nil],json.test) 
  end
end
