# encoding: utf-8

require 'cases/helper'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlXMLTest < ActiveRecord::TestCase
  class XmlDataType < ActiveRecord::Base
    self.table_name = 'xml_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('xml_data_type') do |t|
          t.xml 'payload', default: {}
        end
      end
    rescue ActiveRecord::StatementInvalid
      return skip "do not test on PG without xml"
    end
    @column = XmlDataType.columns.find { |c| c.name == 'payload' }
  end

  def teardown
    @connection.execute 'drop table if exists xml_data_type'
  end

  def test_column
    assert_equal :xml, @column.type
  end

  def test_null_xml
    @connection.execute %q|insert into xml_data_type (payload) VALUES(null)|
    assert_nil XmlDataType.first.payload
  end
end
