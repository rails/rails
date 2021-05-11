# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlIntervalTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class IntervalDataType < ActiveRecord::Base
    attribute :maximum_term, :interval
    attribute :minimum_term, :interval, precision: 3
    attribute :default_term, :interval
    attribute :all_terms,    :interval, array: true
    attribute :legacy_term,  :string
  end if current_adapter?(:PostgreSQLAdapter)

  class DeprecatedIntervalDataType < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.create_table("interval_data_types") do |t|
        t.interval "maximum_term"
        t.interval "minimum_term", precision: 3
        t.interval "default_term", default: "P3Y"
        t.interval "all_terms", array: true
        t.interval "legacy_term"
      end
      @connection.create_table("deprecated_interval_data_types") do |t|
        t.interval "duration"
      end
    end
    @column_max = IntervalDataType.columns_hash["maximum_term"]
    @column_min = IntervalDataType.columns_hash["minimum_term"]
    assert(@column_max.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLColumn))
    assert(@column_min.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLColumn))
    assert_nil @column_max.precision
    assert_equal 3,   @column_min.precision
  end

  teardown do
    @connection.execute "DROP TABLE IF EXISTS interval_data_types"
    @connection.execute "DROP TABLE IF EXISTS deprecated_interval_data_types"
  end

  def test_column
    assert_equal :interval,     @column_max.type
    assert_equal :interval,     @column_min.type
    assert_equal "interval",    @column_max.sql_type
    assert_equal "interval(3)", @column_min.sql_type
  end

  def test_interval_type
    IntervalDataType.create!(
      maximum_term: 6.year + 5.month + 4.days + 3.hours + 2.minutes + 1.seconds,
      minimum_term: 1.year + 2.month + 3.days + 4.hours + 5.minutes + (6.234567).seconds,
      all_terms:    [1.month, 1.year, 1.hour],
      legacy_term:  "33 years",
    )
    i = IntervalDataType.last!
    assert_equal "P6Y5M4DT3H2M1S",     i.maximum_term.iso8601
    assert_equal "P1Y2M3DT4H5M6.235S", i.minimum_term.iso8601
    assert_equal "P3Y",                i.default_term.iso8601
    assert_equal %w[ P1M P1Y PT1H ],   i.all_terms.map(&:iso8601)
    assert_equal "P33Y",               i.legacy_term
  end

  def test_interval_type_cast_from_invalid_string
    i = IntervalDataType.create!(maximum_term: "1 year 2 minutes")
    i.reload
    assert_nil i.maximum_term
  end

  def test_interval_type_cast_from_numeric
    i = IntervalDataType.create!(minimum_term: 36000)
    i.reload
    assert_equal "PT10H",  i.minimum_term.iso8601
  end

  def test_interval_type_cast_string_and_numeric_from_user
    i = IntervalDataType.new(maximum_term: "P1YT2M", minimum_term: "PT10H", legacy_term: "P1DT1H")
    assert i.maximum_term.is_a?(ActiveSupport::Duration)
    assert i.legacy_term.is_a?(String)
    assert_equal "P1YT2M", i.maximum_term.iso8601
    assert_equal "PT10H",  i.minimum_term.iso8601
    assert_equal "P1DT1H", i.legacy_term
  end

  def test_average_interval_type
    IntervalDataType.create!([{ maximum_term: 6.years }, { maximum_term: 4.months }])
    value = IntervalDataType.average(:maximum_term)

    assert_equal 3.years + 2.months, value
    assert_instance_of ActiveSupport::Duration, value
  end

  def test_deprecated_legacy_type
    assert_deprecated do
      DeprecatedIntervalDataType.new
    end
  end

  def test_schema_dump_with_default_value
    output = dump_table_schema "interval_data_types"
    assert_match %r{t\.interval "default_term", default: "P3Y"}, output
  end
end
