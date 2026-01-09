# frozen_string_literal: true

require "cases/helper"

class PostgreSQLPartitionsTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @previous_unlogged_tables = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables
    @connection = ActiveRecord::Base.lease_connection
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = false
  end

  def teardown
    @connection.drop_table "partitioned_events", if_exists: true
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = @previous_unlogged_tables
  end

  def test_partitions_table_exists
    skip unless ActiveRecord::Base.lease_connection.database_version >= 100000
    @connection.create_table :partitioned_events, force: true, id: false,
      options: "partition by range (issued_at)" do |t|
      t.timestamp :issued_at
    end
    assert @connection.table_exists?("partitioned_events")
  end
end
