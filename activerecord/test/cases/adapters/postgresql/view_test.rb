require "cases/helper"

class ViewTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  SCHEMA_NAME = 'test_schema'
  TABLE_NAME = 'things'
  VIEW_NAME = 'view_things'
  COLUMNS = [
    'id integer',
    'name character varying(50)',
    'email character varying(50)',
    'moment timestamp without time zone'
  ]

  class ThingView < ActiveRecord::Base
    self.table_name = 'test_schema.view_things'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute "CREATE SCHEMA #{SCHEMA_NAME} CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.\"#{TABLE_NAME}.table\" (#{COLUMNS.join(',')})"
    @connection.execute "CREATE VIEW #{SCHEMA_NAME}.#{VIEW_NAME} AS SELECT id,name,email,moment FROM #{SCHEMA_NAME}.#{TABLE_NAME}"
  end

  def teardown
    @connection.execute "DROP SCHEMA #{SCHEMA_NAME} CASCADE"
  end

  def test_table_exists
    name = ThingView.table_name
    assert @connection.table_exists?(name), "'#{name}' table should exist"
  end

  def test_column_definitions
    assert_nothing_raised do
      assert_equal COLUMNS, columns("#{SCHEMA_NAME}.#{VIEW_NAME}")
    end
  end

  private
    def columns(table_name)
      @connection.send(:column_definitions, table_name).map do |name, type, default|
        "#{name} #{type}" + (default ? " default #{default}" : '')
      end
    end

end
