# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlJSONTest < ActiveRecord::TestCase
  class JsonDataType < ActiveRecord::Base
    self.table_name = 'json_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('json_data_type') do |t|
          t.json 'payload', :default => {}
        end
      end
    rescue ActiveRecord::StatementInvalid
      return skip "do not test on PG without json"
    end
    @column = JsonDataType.columns.find { |c| c.name == 'payload' }
  end

  def teardown
    @connection.execute 'drop table if exists json_data_type'
  end

  def test_column
    assert_equal :json, @column.type
  end

  def test_type_cast_json
    assert @column

    data = "{\"a_key\":\"a_value\"}"
    hash = @column.class.string_to_json data
    assert_equal({'a_key' => 'a_value'}, hash)
    assert_equal({'a_key' => 'a_value'}, @column.type_cast(data))

    assert_equal({}, @column.type_cast("{}"))
    assert_equal({'key'=>nil}, @column.type_cast('{"key": null}'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, @column.type_cast(%q({"c":"}", "\"a\"":"b \"a b"})))
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
end
