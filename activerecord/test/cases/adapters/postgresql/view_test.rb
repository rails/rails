require "cases/helper"

module ViewTestConcern
  extend ActiveSupport::Concern

  included do
    self.use_transactional_fixtures = false
    mattr_accessor :view_type
  end

  SCHEMA_NAME = 'test_schema'
  TABLE_NAME = 'things'
  COLUMNS = [
    'id integer',
    'name character varying(50)',
    'email character varying(50)',
    'moment timestamp without time zone'
  ]

  class ThingView < ActiveRecord::Base
  end

  def setup
    super
    ThingView.table_name = "#{SCHEMA_NAME}.#{view_type}_things"

    @connection = ActiveRecord::Base.connection
    @connection.execute "CREATE SCHEMA #{SCHEMA_NAME} CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "CREATE #{view_type.humanize} #{ThingView.table_name} AS SELECT * FROM #{SCHEMA_NAME}.#{TABLE_NAME}"
  end

  def teardown
    super
    @connection.execute "DROP SCHEMA #{SCHEMA_NAME} CASCADE"
  end

  def test_table_exists
    name = ThingView.table_name
    assert @connection.table_exists?(name), "'#{name}' table should exist"
  end

  def test_column_definitions
    assert_nothing_raised do
      assert_equal COLUMNS, columns(ThingView.table_name)
    end
  end

  private
    def columns(table_name)
      @connection.send(:column_definitions, table_name).map do |name, type, default|
        "#{name} #{type}" + (default ? " default #{default}" : '')
      end
    end

end

class ViewTest < ActiveRecord::TestCase
  include ViewTestConcern
  self.view_type = 'view'
end

if ActiveRecord::Base.connection.supports_materialized_views?
  class MaterializedViewTest < ActiveRecord::TestCase
    include ViewTestConcern
    self.view_type = 'materialized_view'
  end
end
