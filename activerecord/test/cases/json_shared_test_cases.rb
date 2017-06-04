require "support/schema_dumping_helper"

module JSONSharedTestCases
  include SchemaDumpingHelper

  class JsonDataType < ActiveRecord::Base
    self.table_name = "json_data_type"

    store_accessor :settings, :resolution
  end

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table :json_data_type, if_exists: true
    klass.reset_column_information
  end

  def test_column
    column = klass.columns_hash["payload"]
    assert_equal column_type, column.type
    assert_equal column_type.to_s, column.sql_type

    type = klass.type_for_attribute("payload")
    assert_not type.binary?
  end

  def test_change_table_supports_json
    @connection.change_table("json_data_type") do |t|
      t.public_send column_type, "users"
    end
    klass.reset_column_information
    column = klass.columns_hash["users"]
    assert_equal column_type, column.type
    assert_equal column_type.to_s, column.sql_type
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
    @connection.execute(%q|insert into json_data_type (payload) VALUES ('{"k":"v"}')|)
    x = klass.first
    x.payload = { '"a\'' => "b" }
    assert x.save!
  end

  def test_select
    @connection.execute(%q|insert into json_data_type (payload) VALUES ('{"k":"v"}')|)
    x = klass.first
    assert_equal({ "k" => "v" }, x.payload)
  end

  def test_select_multikey
    @connection.execute(%q|insert into json_data_type (payload) VALUES ('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}')|)
    x = klass.first
    assert_equal({ "k1" => "v1", "k2" => "v2", "k3" => [1, 2, 3] }, x.payload)
  end

  def test_null_json
    @connection.execute("insert into json_data_type (payload) VALUES(null)")
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

    json.update_attributes(payload: nil)
    x = klass.where(payload: nil).first
    assert_equal(json.reload, x)
  end

  def test_select_array_json_value
    @connection.execute(%q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|)
    x = klass.first
    assert_equal(["v0", { "k1" => "v1" }], x.payload)
  end

  def test_rewrite_array_json_value
    @connection.execute(%q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|)
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

    y = YAML.load(YAML.dump(x))
    assert_equal "320×480", y.resolution
  end

  def test_changes_in_place
    json = klass.new
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

  def test_changes_in_place_with_ruby_object
    time = Time.now.utc
    json = klass.create!(payload: time)

    json.reload
    assert_not json.changed?

    json.payload = time
    assert_not json.changed?
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

  private
    def klass
      JsonDataType
    end
end
