# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlByteaTest < ActiveRecord::TestCase
  class ByteaDataType < ActiveRecord::Base
    self.table_name = 'bytea_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('bytea_data_type') do |t|
          t.binary 'payload'
          t.binary 'serialized'
        end
      end
    end
    @column = ByteaDataType.columns.find { |c| c.name == 'payload' }
    assert(@column.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLColumn))
  end

  def teardown
    @connection.execute 'drop table if exists bytea_data_type'
  end

  def test_column
    assert_equal :binary, @column.type
  end

  def test_type_cast_binary_converts_the_encoding
    assert @column

    data = "\u001F\x8B"
    assert_equal('UTF-8', data.encoding.name)
    assert_equal('ASCII-8BIT', @column.type_cast(data).encoding.name)
  end

  def test_type_cast_binary_value
    data = "\u001F\x8B".force_encoding("BINARY")
    assert_equal(data, @column.type_cast(data))
  end

  def test_type_case_nil
    assert_equal(nil, @column.type_cast(nil))
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
    assert_equal(nil, record.payload)
    record.delete
  end

  def test_write_value
    data = "\u001F"
    record = ByteaDataType.create(payload: data)
    assert_not record.new_record?
    assert_equal(data, record.payload)
  end

  def test_write_binary
    data = File.read(File.join(File.dirname(__FILE__), '..', '..', '..', 'assets', 'example.log'))
    assert(data.size > 1)
    record = ByteaDataType.create(payload: data)
    assert_not record.new_record?
    assert_equal(data, record.payload)
    assert_equal(data, ByteaDataType.where(id: record.id).first.payload)
  end

  def test_write_nil
    record = ByteaDataType.create(payload: nil)
    assert_not record.new_record?
    assert_equal(nil, record.payload)
    assert_equal(nil, ByteaDataType.where(id: record.id).first.payload)
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
end
