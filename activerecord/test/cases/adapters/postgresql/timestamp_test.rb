# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/topic"

class PostgresqlTimestampTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlTimestampWithZone < ActiveRecord::Base; end

  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.execute("INSERT INTO postgresql_timestamp_with_zones (id, time) VALUES (1, '2010-01-01 10:00:00-1')")
  end

  teardown do
    PostgresqlTimestampWithZone.delete_all
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support_and_no_time_zone_set
    with_timezone_config default: :utc, aware_attributes: true do
      @connection.reconnect!

      timestamp = PostgresqlTimestampWithZone.find(1)
      assert_equal Time.utc(2010, 1, 1, 11, 0, 0), timestamp.time
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
      assert_equal Time.utc(2010, 1, 1, 11, 0, 0), timestamp.time
      assert_instance_of Time, timestamp.time
    end
  ensure
    @connection.reconnect!
  end
end

class PostgresqlTimestampWithAwareTypesTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlTimestampWithZone < ActiveRecord::Base; end

  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.execute("INSERT INTO postgresql_timestamp_with_zones (id, time) VALUES (1, '2010-01-01 10:00:00-1')")
  end

  teardown do
    PostgresqlTimestampWithZone.delete_all
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support_and_time_zone_set
    with_timezone_config default: :utc, aware_attributes: true, zone: "Pacific Time (US & Canada)", aware_types: [:timestamptz, :datetime, :time] do
      @connection.reconnect!

      timestamp = PostgresqlTimestampWithZone.find(1)
      assert_equal Time.utc(2010, 1, 1, 11, 0, 0), timestamp.time
      assert_instance_of ActiveSupport::TimeWithZone, timestamp.time
    end
  ensure
    @connection.reconnect!
  end
end

class PostgresqlTimestampWithTimeZoneTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlTimestampWithZone < ActiveRecord::Base; end

  self.use_transactional_tests = false

  setup do
    with_postgresql_datetime_type(:timestamptz) do
      @connection = ActiveRecord::Base.lease_connection
      @connection.execute("INSERT INTO postgresql_timestamp_with_zones (id, time) VALUES (1, '2010-01-01 10:00:00-1')")
    end
  end

  teardown do
    PostgresqlTimestampWithZone.delete_all
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support_and_timestamptz_and_no_time_zone_set
    with_postgresql_datetime_type(:timestamptz) do
      with_timezone_config default: :utc, aware_attributes: true, aware_types: [:timestamptz, :datetime, :time] do
        @connection.reconnect!

        timestamp = PostgresqlTimestampWithZone.find(1)
        assert_equal Time.utc(2010, 1, 1, 11, 0, 0), timestamp.time
        assert_instance_of Time, timestamp.time
      end
    end
  ensure
    @connection.reconnect!
  end

  def test_timestamp_with_zone_values_with_rails_time_zone_support_and_timestamptz_and_time_zone_set
    with_postgresql_datetime_type(:timestamptz) do
      with_timezone_config default: :utc, aware_attributes: true, zone: "Pacific Time (US & Canada)", aware_types: [:timestamptz, :datetime, :time] do
        @connection.reconnect!

        timestamp = PostgresqlTimestampWithZone.find(1)
        assert_equal Time.utc(2010, 1, 1, 11, 0, 0), timestamp.time
        assert_instance_of ActiveSupport::TimeWithZone, timestamp.time
      end
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
    d = Developer.find_by_sql("select 'infinity'::timestamp as legacy_updated_at")
    assert_predicate d.first.updated_at, :infinite?, "timestamp should be infinite"

    d = Developer.find_by_sql("select '-infinity'::timestamp as legacy_updated_at")
    time = d.first.updated_at
    assert_predicate time, :infinite?, "timestamp should be infinite"
    assert_operator time, :<, 0
  end

  def test_save_infinity_and_beyond
    d = Developer.create!(name: "aaron", updated_at: 1.0 / 0.0)
    assert_equal(1.0 / 0.0, d.updated_at)

    d = Developer.create!(name: "aaron", updated_at: -1.0 / 0.0)
    assert_equal(-1.0 / 0.0, d.updated_at)
  end

  def test_bc_timestamp
    date = Time.new(0) - 1.week
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

class PostgresqlTimestampMigrationTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlTimestampWithZone < ActiveRecord::Base; end
  class PostgresqlTimestampPrecision < ActiveRecord::Base; end

  def test_adds_column_as_timestamp
    original, $stdout = $stdout, StringIO.new

    ActiveRecord::Migration.new.add_column :postgresql_timestamp_with_zones, :times, :datetime

    assert_equal({ "data_type" => "timestamp without time zone" },
                 PostgresqlTimestampWithZone.lease_connection.execute("select data_type from information_schema.columns where column_name = 'times'").to_a.first)
  ensure
    $stdout = original
  end

  def test_adds_column_as_timestamptz_if_datetime_type_changed
    original, $stdout = $stdout, StringIO.new

    with_postgresql_datetime_type(:timestamptz) do
      ActiveRecord::Migration.new.add_column :postgresql_timestamp_with_zones, :times, :datetime

      assert_equal({ "data_type" => "timestamp with time zone" },
                   PostgresqlTimestampWithZone.lease_connection.execute("select data_type from information_schema.columns where column_name = 'times'").to_a.first)
    end
  ensure
    $stdout = original
  end

  def test_adds_column_as_custom_type
    original, $stdout = $stdout, StringIO.new

    PostgresqlTimestampWithZone.lease_connection.execute("CREATE TYPE custom_time_format AS ENUM ('past', 'present', 'future');")

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:datetimes_as_enum] = { name: "custom_time_format" }
    with_postgresql_datetime_type(:datetimes_as_enum) do
      ActiveRecord::Migration.new.add_column :postgresql_timestamp_with_zones, :times, :datetime, precision: nil

      assert_equal({ "data_type" => "USER-DEFINED", "udt_name" => "custom_time_format" },
                   PostgresqlTimestampWithZone.lease_connection.execute("select data_type, udt_name from information_schema.columns where column_name = 'times'").to_a.first)
    end
  ensure
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES.delete(:datetimes_as_enum)
    $stdout = original
  end

  def test_timestamp_precision_metadata_uses_postgresql_default_for_bare_timestamp_types
    with_timestamp_precision_table do
      columns = columns_hash(PostgresqlTimestampPrecision)

      assert_equal 6, columns["bare_timestamp"].precision
      assert_equal 6, columns["bare_timestamptz"].precision
      assert_equal 6, columns["explicit_timestamp_6"].precision
      assert_equal 0, columns["explicit_timestamp_0"].precision
      assert_equal 3, columns["explicit_timestamp_3"].precision
    end
  end

  def test_time_precision_metadata_uses_postgresql_default_for_bare_time_types
    with_timestamp_precision_table do
      columns = columns_hash(PostgresqlTimestampPrecision)

      assert_equal 6, columns["bare_time"].precision
      assert_equal 6, columns["bare_timetz"].precision
      assert_equal 0, columns["explicit_time_0"].precision
      assert_equal 3, columns["explicit_timetz_3"].precision
    end
  end

  def test_bare_timestamp_type_casting_uses_postgresql_default_precision
    with_timestamp_precision_table do
      time = ::Time.now.change(nsec: 123456789)
      record = PostgresqlTimestampPrecision.new(bare_timestamp: time, bare_timestamptz: time)

      assert_equal 123456000, record.bare_timestamp.nsec
      assert_equal 123456000, record.bare_timestamptz.nsec
    end
  end

  private
    def with_timestamp_precision_table
      connection = PostgresqlTimestampPrecision.lease_connection
      connection.drop_table :postgresql_timestamp_precisions, if_exists: true
      connection.execute(<<~SQL)
        CREATE TABLE postgresql_timestamp_precisions (
          bare_timestamp timestamp without time zone,
          bare_timestamptz timestamp with time zone,
          explicit_timestamp_6 timestamp(6) without time zone,
          explicit_timestamp_0 timestamp(0) without time zone,
          explicit_timestamp_3 timestamp(3) without time zone,
          bare_time time without time zone,
          bare_timetz time with time zone,
          explicit_time_0 time(0) without time zone,
          explicit_timetz_3 time(3) with time zone
        )
      SQL
      PostgresqlTimestampPrecision.reset_column_information
      yield
    ensure
      PostgresqlTimestampPrecision.reset_column_information
      connection&.drop_table :postgresql_timestamp_precisions, if_exists: true
    end

    def columns_hash(model)
      model.columns.index_by(&:name)
    end
end
