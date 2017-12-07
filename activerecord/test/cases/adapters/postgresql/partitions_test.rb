# frozen_string_literal: true

require "cases/helper"

class PostgreSQLPartitionsTest < ActiveRecord::PostgreSQLTestCase
  COLUMNS = [
    "id serial primary key",
    "blob character varying(50)",
    "created_at timestamp not null default now()"
  ]
  def test_partitions_table_exists
    @connection = ActiveRecord::Base.connection
    if @connection.send(:postgresql_version) >= 10000
      @connection.execute "CREATE TABLE events (#{COLUMNS.join(',')}) PARTITION BY RANGE (created_at)"
      @connection.execute "CREATE TABLE events_20170101 PARTITION OF events FOR VALUES FROM ('2017-01-01') TO ('2017-01-02')"
      assert @connection.table_exists?("events")
    end
  end
end
