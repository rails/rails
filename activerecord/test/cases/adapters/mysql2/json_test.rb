require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.connection.supports_json?
  class Mysql2JSONTest < ActiveRecord::Mysql2TestCase
    include SchemaDumpingHelper
    self.use_transactional_tests = false

    class JsonDataType < ActiveRecord::Base
      self.table_name = "json_data_type"

      store_accessor :settings, :resolution
    end

    def setup
      @connection = ActiveRecord::Base.connection
      begin
        @connection.create_table("json_data_type") do |t|
          t.json "payload"
          t.json "settings"
        end
      end
    end

    def teardown
      @connection.drop_table :json_data_type, if_exists: true
      JsonDataType.reset_column_information
    end

    def test_column
      column = JsonDataType.columns_hash["payload"]
      assert_equal :json, column.type
      assert_equal "json", column.sql_type

      type = JsonDataType.type_for_attribute("payload")
      assert_not type.binary?
    end

    def test_change_table_supports_json
      @connection.change_table("json_data_type") do |t|
        t.json "users"
      end
      JsonDataType.reset_column_information
      column = JsonDataType.columns_hash["users"]
      assert_equal :json, column.type
    end

    def test_schema_dumping
      output = dump_table_schema("json_data_type")
      assert_match(/t\.json\s+"settings"/, output)
    end

    def test_cast_value_on_write
      x = JsonDataType.new payload: { "string" => "foo", :symbol => :bar }
      assert_equal({ "string" => "foo", :symbol => :bar }, x.payload_before_type_cast)
      assert_equal({ "string" => "foo", "symbol" => "bar" }, x.payload)
      x.save
      assert_equal({ "string" => "foo", "symbol" => "bar" }, x.reload.payload)
    end

    def test_type_cast_json
      type = JsonDataType.type_for_attribute("payload")

      data = "{\"a_key\":\"a_value\"}"
      hash = type.deserialize(data)
      assert_equal({ "a_key" => "a_value" }, hash)
      assert_equal({ "a_key" => "a_value" }, type.deserialize(data))

      assert_equal({}, type.deserialize("{}"))
      assert_equal({ "key" => nil }, type.deserialize('{"key": null}'))
      assert_equal({ "c" => "}", '"a"' => 'b "a b' }, type.deserialize(%q({"c":"}", "\"a\"":"b \"a b"})))
    end

    def test_rewrite
      @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
      x = JsonDataType.first
      x.payload = { '"a\'' => "b" }
      assert x.save!
    end

    def test_select
      @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
      x = JsonDataType.first
      assert_equal({ "k" => "v" }, x.payload)
    end

    def test_select_multikey
      @connection.execute %q|insert into json_data_type (payload) VALUES ('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}')|
      x = JsonDataType.first
      assert_equal({ "k1" => "v1", "k2" => "v2", "k3" => [1, 2, 3] }, x.payload)
    end

    def test_null_json
      @connection.execute "insert into json_data_type (payload) VALUES(null)"
      x = JsonDataType.first
      assert_equal(nil, x.payload)
    end

    def test_select_array_json_value
      @connection.execute %q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
      x = JsonDataType.first
      assert_equal(["v0", { "k1" => "v1" }], x.payload)
    end

    def test_select_nil_json_after_create
      json = JsonDataType.create(payload: nil)
      x = JsonDataType.where(payload: nil).first
      assert_equal(json, x)
    end

    def test_select_nil_json_after_update
      json = JsonDataType.create(payload: "foo")
      x = JsonDataType.where(payload: nil).first
      assert_equal(nil, x)

      json.update_attributes payload: nil
      x = JsonDataType.where(payload: nil).first
      assert_equal(json.reload, x)
    end

    def test_rewrite_array_json_value
      @connection.execute %q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
      x = JsonDataType.first
      x.payload = ["v1", { "k2" => "v2" }, "v3"]
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

    def test_duplication_with_store_accessors
      x = JsonDataType.new(resolution: "320×480")
      assert_equal "320×480", x.resolution

      y = x.dup
      assert_equal "320×480", y.resolution
    end

    def test_yaml_round_trip_with_store_accessors
      x = JsonDataType.new(resolution: "320×480")
      assert_equal "320×480", x.resolution

      y = YAML.load(YAML.dump(x))
      assert_equal "320×480", y.resolution
    end

    def test_changes_in_place
      json = JsonDataType.new
      assert_not json.changed?

      json.payload = { "one" => "two" }
      assert json.changed?
      assert json.payload_changed?

      json.save!
      assert_not json.changed?

      json.payload["three"] = "four"
      assert json.payload_changed?

      json.save!
      json.reload

      assert_equal({ "one" => "two", "three" => "four" }, json.payload)
      assert_not json.changed?
    end

    def test_assigning_string_literal
      json = JsonDataType.create(payload: "foo")
      assert_equal "foo", json.payload
    end

    def test_assigning_number
      json = JsonDataType.create(payload: 1.234)
      assert_equal 1.234, json.payload
    end

    def test_assigning_boolean
      json = JsonDataType.create(payload: true)
      assert_equal true, json.payload
    end
  end
end
