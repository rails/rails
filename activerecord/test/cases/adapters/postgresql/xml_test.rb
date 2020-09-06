# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

class PostgresqlXMLTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper
  class XmlDataType < ActiveRecord::Base
    self.table_name = 'xml_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('xml_data_type') do |t|
      t.xml 'payload'
    end
    @column = XmlDataType.columns_hash['payload']
  end

  teardown do
    @connection.drop_table 'xml_data_type', if_exists: true
  end

  def test_column
    assert_equal :xml, @column.type
  end

  def test_null_xml
    @connection.execute 'insert into xml_data_type (payload) VALUES(null)'
    assert_nil XmlDataType.first.payload
  end

  def test_round_trip
    data = XmlDataType.new(payload: '<foo>bar</foo>')
    assert_equal '<foo>bar</foo>', data.payload
    data.save!
    assert_equal '<foo>bar</foo>', data.reload.payload
  end

  def test_update_all
    data = XmlDataType.create!
    XmlDataType.update_all(payload: '<bar>baz</bar>')
    assert_equal '<bar>baz</bar>', data.reload.payload
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema('xml_data_type')
    assert_match %r{t\.xml "payload"}, output
  end
end
