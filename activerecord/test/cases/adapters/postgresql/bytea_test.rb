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
