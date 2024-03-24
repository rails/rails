# frozen_string_literal: true

require "cases/helper"

class PostgreSQLPartitionsTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    @connection.drop_table "partitioned_events", if_exists: true
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
