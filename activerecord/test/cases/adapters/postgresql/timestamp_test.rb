require "cases/helper"
require "models/developer"
require "models/topic"

class PostgresqlTimestampTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlTimestampWithZone < ActiveRecord::Base; end

  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.execute("INSERT INTO postgresql_timestamp_with_zones (id, time) VALUES (1, '2010-01-01 10:00:00-1')")
  end

  teardown do
    PostgresqlTimestampWithZone.delete_all
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support
    with_timezone_config default: :utc, aware_attributes: true do
      @connection.reconnect!

      timestamp = PostgresqlTimestampWithZone.find(1)
      assert_equal Time.utc(2010,1,1, 11,0,0), timestamp.time
      assert_instance_of Time, timestamp.time
    end
  ensure
    @connection.reconnect!
  end

  def test_timestamp_with_zone_values_without_rails_time_zone_support
    with_timezone_config default: :local, aware_attributes: false do
      @connection.reconnect!
      # make sure to use a non-UTC time zone
      @connection.execute("SET time zone 'America/Jamaica'", "SCHEMA")

      timestamp = PostgresqlTimestampWithZone.find(1)
      assert_equal Time.utc(2010,1,1, 11,0,0), timestamp.time
      assert_instance_of Time, timestamp.time
    end
  ensure
    @connection.reconnect!
  end
end

class PostgresqlTimestampFixtureTest < ActiveRecord::PostgreSQLTestCase
  fixtures :topics

  def test_group_by_date
    keys = Topic.group("date_trunc('month', created_at)").count.keys
    assert_operator keys.length, :>, 0
    keys.each { |k| assert_kind_of Time, k }
  end

  def test_load_infinity_and_beyond
    d = Developer.find_by_sql("select 'infinity'::timestamp as updated_at")
    assert d.first.updated_at.infinite?, "timestamp should be infinite"

    d = Developer.find_by_sql("select '-infinity'::timestamp as updated_at")
    time = d.first.updated_at
    assert time.infinite?, "timestamp should be infinite"
    assert_operator time, :<, 0
  end

  def test_save_infinity_and_beyond
    d = Developer.create!(name: "aaron", updated_at: 1.0 / 0.0)
    assert_equal(1.0 / 0.0, d.updated_at)

    d = Developer.create!(name: "aaron", updated_at: -1.0 / 0.0)
    assert_equal(-1.0 / 0.0, d.updated_at)
  end

  def test_bc_timestamp
    date = Date.new(0) - 1.week
    Developer.create!(name: "aaron", updated_at: date)
    assert_equal date, Developer.find_by_name("aaron").updated_at
  end

  def test_bc_timestamp_leap_year
    date = Time.utc(-4, 2, 29)
    Developer.create!(name: "taihou", updated_at: date)
    assert_equal date, Developer.find_by_name("taihou").updated_at
  end

  def test_bc_timestamp_year_zero
    date = Time.utc(0, 4, 7)
    Developer.create!(name: "yahagi", updated_at: date)
    assert_equal date, Developer.find_by_name("yahagi").updated_at
  end
end
