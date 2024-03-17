# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class UnloggedTablesTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  TABLE_NAME = "things"
  LOGGED_FIELD = "relpersistence"
  LOGGED_QUERY = "SELECT #{LOGGED_FIELD} FROM pg_class WHERE relname = '#{TABLE_NAME}'"
  LOGGED = "p"
  UNLOGGED = "u"
  TEMPORARY = "t"

  class Thing < ActiveRecord::Base
    self.table_name = TABLE_NAME
  end

  def setup
    @previous_unlogged_tables = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables
    @connection = ActiveRecord::Base.lease_connection
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = false
  end

  teardown do
    @connection.drop_table TABLE_NAME, if_exists: true
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = @previous_unlogged_tables
  end

  def test_logged_by_default
    @connection.create_table(TABLE_NAME) do |t|
    end
    assert_equal @connection.execute(LOGGED_QUERY).first[LOGGED_FIELD], LOGGED
  end

  def test_unlogged_in_test_environment_when_unlogged_setting_enabled
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true

    @connection.create_table(TABLE_NAME) do |t|
    end
    assert_equal @connection.execute(LOGGED_QUERY).first[LOGGED_FIELD], UNLOGGED
  end

  def test_not_included_in_schema_dump
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true

    @connection.create_table(TABLE_NAME) do |t|
    end
    assert_no_match(/unlogged/i, dump_table_schema(TABLE_NAME))
  end

  def test_not_changed_in_change_table
    @connection.create_table(TABLE_NAME) do |t|
    end

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true

    @connection.change_table(TABLE_NAME) do |t|
      t.column :name, :string
    end
    assert_equal @connection.execute(LOGGED_QUERY).first[LOGGED_FIELD], LOGGED
  end

  def test_gracefully_handles_temporary_tables
    @connection.create_table(TABLE_NAME, temporary: true) do |t|
    end

    # Temporary tables are already unlogged, though this query results in a
    # different result ("t" vs. "u"). This test is really just checking that we
    # didn't try to run `CREATE TEMPORARY UNLOGGED TABLE`, which would result in
    # a PostgreSQL error.
    assert_equal @connection.execute(LOGGED_QUERY).first[LOGGED_FIELD], TEMPORARY
  end
end
