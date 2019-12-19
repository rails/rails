# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlByteaTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class ByteaDataType < ActiveRecord::Base
    self.table_name = "bytea_data_type"
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table("bytea_data_type") do |t|
          t.binary "payload"
          t.binary "serialized"
        end
      end
    end
    @column = ByteaDataType.columns_hash["payload"]
    @type = ByteaDataType.type_for_attribute("payload")
  end

  teardown do
    @connection.drop_table "bytea_data_type", if_exists: true
  end

  def test_column
    assert @column.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLColumn)
    assert_equal :binary, @column.type
  end

  def test_binary_columns_are_limitless_the_upper_limit_is_one_GB
    assert_equal "bytea", @connection.type_to_sql(:binary, limit: 100_000)
    assert_raise ArgumentError do
      @connection.type_to_sql(:binary, limit: 4294967295)
    end
  end

  def test_type_cast_binary_converts_the_encoding
    assert @column

    data = "\u001F\x8B"
    assert_equal("UTF-8", data.encoding.name)
    assert_equal("ASCII-8BIT", @type.deserialize(data).encoding.name)
  end

  def test_type_cast_binary_value
    data = (+"\u001F\x8B").force_encoding("BINARY")
    assert_equal(data, @type.deserialize(data))
  end

  def test_type_case_nil
    assert_nil(@type.deserialize(nil))
  end

  def test_read_value
    data = "\u001F"
    @connection.execute "insert into bytea_data_type (payload) VALUES ('#{data}')"
    record = ByteaDataType.first
    assert_equal(data, record.payload)
    record.delete
  end

  def test_read_nil_value
    @connection.execute "insert into bytea_data_type (payload) VALUES (null)"
    record = ByteaDataType.first
    assert_nil(record.payload)
    record.delete
  end

  def test_write_value
    data = "\u001F"
    record = ByteaDataType.create(payload: data)
    assert_not_predicate record, :new_record?
    assert_equal(data, record.payload)
  end

  def test_via_to_sql
    data = "'\u001F\\"
    ByteaDataType.create(payload: data)
    sql = ByteaDataType.where(payload: data).select(:payload).to_sql
    result = @connection.query(sql)
    assert_equal([[data]], result)
  end

  def test_via_to_sql_with_complicating_connection
    Thread.new do
      other_conn = ActiveRecord::Base.connection
      other_conn.execute("SET standard_conforming_strings = off")
      other_conn.execute("SET escape_string_warning = off")
    end.join

    test_via_to_sql
  end

  def test_write_binary
    data = File.read(File.join(__dir__, "..", "..", "..", "assets", "example.log"))
    assert(data.size > 1)
    record = ByteaDataType.create(payload: data)
    assert_not_predicate record, :new_record?
    assert_equal(data, record.payload)
    assert_equal(data, ByteaDataType.where(id: record.id).first.payload)
  end

  def test_write_nil
    record = ByteaDataType.create(payload: nil)
    assert_not_predicate record, :new_record?
    assert_nil(record.payload)
    assert_nil(ByteaDataType.where(id: record.id).first.payload)
  end

  class Serializer
    def load(str); str; end
    def dump(str); str; end
  end

  def test_serialize
    klass = Class.new(ByteaDataType) {
      serialize :serialized, Serializer.new
    }
    obj = klass.new
    obj.serialized = "hello world"
    obj.save!
    obj.reload
    assert_equal "hello world", obj.serialized
  end

  def test_schema_dumping
    output = dump_table_schema("bytea_data_type")
    assert_match %r{t\.binary\s+"payload"$}, output
    assert_match %r{t\.binary\s+"serialized"$}, output
  end
end
