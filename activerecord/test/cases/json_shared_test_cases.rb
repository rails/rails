# frozen_string_literal: true

require "support/schema_dumping_helper"
require "pp"

module JSONSharedTestCases
  include SchemaDumpingHelper

  class JsonDataType < ActiveRecord::Base
    self.table_name = "json_data_type"

    store_accessor :settings, :resolution
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    @connection.drop_table :json_data_type, if_exists: true
    klass.reset_column_information
  end

  def test_column
    column = klass.columns_hash["payload"]
    assert_equal column_type, column.type
    assert_type_match column_type, column.sql_type

    type = klass.type_for_attribute("payload")
    assert_not_predicate type, :binary?
  end

  def test_change_table_supports_json
    @connection.change_table("json_data_type") do |t|
      t.public_send column_type, "users"
    end
    klass.reset_column_information
    column = klass.columns_hash["users"]
    assert_equal column_type, column.type
    assert_type_match column_type, column.sql_type
  end

  def test_schema_dumping
    output = dump_table_schema("json_data_type")
    assert_match(/t\.#{column_type}\s+"settings"/, output)
  end

  def test_cast_value_on_write
    x = klass.new(payload: { "string" => "foo", :symbol => :bar })
    assert_equal({ "string" => "foo", :symbol => :bar }, x.payload_before_type_cast)
    assert_equal({ "string" => "foo", "symbol" => "bar" }, x.payload)
    x.save!
    assert_equal({ "string" => "foo", "symbol" => "bar" }, x.reload.payload)
  end

  def test_type_cast_json
    type = klass.type_for_attribute("payload")

    data = '{"a_key":"a_value"}'
    hash = type.deserialize(data)
    assert_equal({ "a_key" => "a_value" }, hash)
    assert_equal({ "a_key" => "a_value" }, type.deserialize(data))

    assert_equal({}, type.deserialize("{}"))
    assert_equal({ "key" => nil }, type.deserialize('{"key": null}'))
    assert_equal({ "c" => "}", '"a"' => 'b "a b' }, type.deserialize(%q({"c":"}", "\"a\"":"b \"a b"})))
  end

  def test_rewrite
    @connection.execute(insert_statement_per_database('{"k":"v"}'))
    x = klass.first
    x.payload = { '"a\'' => "b" }
    assert x.save!
  end

  def test_select
    @connection.execute(insert_statement_per_database('{"k":"v"}'))
    x = klass.first
    assert_equal({ "k" => "v" }, x.payload)
  end

  def test_select_multikey
    @connection.execute(insert_statement_per_database('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}'))
    x = klass.first
    assert_equal({ "k1" => "v1", "k2" => "v2", "k3" => [1, 2, 3] }, x.payload)
  end

  def test_null_json
    @connection.execute(insert_statement_per_database("null"))
    x = klass.first
    assert_nil(x.payload)
  end

  def test_select_nil_json_after_create
    json = klass.create!(payload: nil)
    x = klass.where(payload: nil).first
    assert_equal(json, x)
  end

  def test_select_nil_json_after_update
    json = klass.create!(payload: "foo")
    x = klass.where(payload: nil).first
    assert_nil(x)

    json.update(payload: nil)
    x = klass.where(payload: nil).first
    assert_equal(json.reload, x)
  end

  def test_select_array_json_value
    @connection.execute(insert_statement_per_database('["v0",{"k1":"v1"}]'))
    x = klass.first
    assert_equal(["v0", { "k1" => "v1" }], x.payload)
  end

  def test_rewrite_array_json_value
    @connection.execute(insert_statement_per_database('["v0",{"k1":"v1"}]'))
    x = klass.first
    x.payload = ["v1", { "k2" => "v2" }, "v3"]
    assert x.save!
  end

  def test_with_store_accessors
    x = klass.new(resolution: "320×480")
    assert_equal "320×480", x.resolution

    x.save!
    x = klass.first
    assert_equal "320×480", x.resolution

    x.resolution = "640×1136"
    x.save!

    x = klass.first
    assert_equal "640×1136", x.resolution
  end

  def test_duplication_with_store_accessors
    x = klass.new(resolution: "320×480")
    assert_equal "320×480", x.resolution

    y = x.dup
    assert_equal "320×480", y.resolution
  end

  def test_yaml_round_trip_with_store_accessors
    x = klass.new(resolution: "320×480")
    assert_equal "320×480", x.resolution

    payload = YAML.dump(x)
    y = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(payload) : YAML.load(payload)
    assert_equal "320×480", y.resolution
  end

  def test_changes_in_place
    json = klass.new
    assert_not_predicate json, :changed?

    json.payload = { "one" => "two" }
    assert_predicate json, :changed?
    assert_predicate json, :payload_changed?

    json.save!
    assert_not_predicate json, :changed?

    json.payload["three"] = "four"
    assert_predicate json, :payload_changed?

    json.save!
    json.reload

    assert_equal({ "one" => "two", "three" => "four" }, json.payload)
    assert_not_predicate json, :changed?
  end

  def test_changes_in_place_ignores_key_order
    json = klass.new
    assert_not_predicate json, :changed?

    json.payload = { "three" => "four", "one" => "two" }
    json.save!
    json.reload

    json.payload = { "three" => "four", "one" => "two" }
    assert_not_predicate json, :changed?

    json.payload = [{ "three" => "four", "one" => "two" }, { "seven" => "eight", "five" => "six" }]
    json.save!
    json.reload

    json.payload = [{ "three" => "four", "one" => "two" }, { "seven" => "eight", "five" => "six" }]
    assert_not_predicate json, :changed?
  end

  def test_changes_in_place_with_ruby_object
    time = Time.now.utc
    json = klass.create!(payload: time)

    json.reload
    assert_not_predicate json, :changed?

    json.payload = time
    assert_not_predicate json, :changed?
  end

  def test_assigning_string_literal
    json = klass.create!(payload: "foo")
    assert_equal "foo", json.payload
  end

  def test_assigning_number
    json = klass.create!(payload: 1.234)
    assert_equal 1.234, json.payload
  end

  def test_assigning_boolean
    json = klass.create!(payload: true)
    assert_equal true, json.payload
  end

  def test_not_compatible_with_serialize_json
    new_klass = Class.new(klass) do
      serialize :payload, coder: JSON
    end
    assert_raises(ActiveRecord::AttributeMethods::Serialization::ColumnNotSerializableError) do
      new_klass.new
    end
  end

  class MySettings
    def initialize(hash); @hash = hash end
    def to_hash; @hash end
    def self.load(hash); new(hash) end
    def self.dump(object); object.to_hash end
  end

  def test_json_with_serialized_attributes
    new_klass = Class.new(klass) do
      serialize :settings, coder: MySettings
    end

    new_klass.create!(settings: MySettings.new("one" => "two"))
    record = new_klass.first

    assert_instance_of MySettings, record.settings
    assert_equal({ "one" => "two" }, record.settings.to_hash)

    record.settings = MySettings.new("three" => "four")
    record.save!

    assert_equal({ "three" => "four" }, record.reload.settings.to_hash)
  end

  class JsonDataTypeWithFilter < ActiveRecord::Base
    self.table_name = "json_data_type"

    attribute :payload, :json

    def self.filter_attributes
      # Rails.application.config.filter_parameters += [:password]
      super + [:password]
    end
  end

  def test_pretty_print
    x = JsonDataTypeWithFilter.create!(payload: {})
    x.payload[11] = "foo"
    io = StringIO.new
    PP.pp(x, io)
    assert io.string
  end

  private
    def klass
      JsonDataType
    end

    def assert_type_match(type, sql_type)
      native_type = ActiveRecord::Base.lease_connection.native_database_types[type][:name]
      assert_match %r(\A#{native_type}\b), sql_type
    end

    def insert_statement_per_database(values)
      "insert into json_data_type (payload) VALUES ('#{values}')"
    end
end
