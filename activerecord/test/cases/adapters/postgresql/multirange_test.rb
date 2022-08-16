# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"

class PostgresqlMultiRange < ActiveRecord::Base
  self.table_name = "postgresql_multiranges"
  self.time_zone_aware_types += [:tsmultirange, :tstzmultirange]
end

class PostgresqlMultiRangeTest < ActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false
  include ConnectionHelper
  include InTimeZone

  def setup
    @connection = PostgresqlMultiRange.connection
    @connection.transaction do
      @connection.create_table("postgresql_multiranges") do |t|
        t.datemultirange :date_multirange
        t.nummultirange  :num_multirange
        t.tsmultirange   :ts_multirange
        t.tstzmultirange :tstz_multirange
        t.int4multirange :int4_multirange
        t.int8multirange :int8_multirange
      end
    end
    PostgresqlMultiRange.reset_column_information

    insert_multirange(
      id: 201,
      date_multirange: "{[''2022-01-02'',''2022-01-04''),[''2022-07-10'',''2022-08-10''],[2022-10-01'',]}",
      num_multirange: "{[5.1,6.3),[-2.3,4.4),[12.1,]}",
      ts_multirange: "{[''2022-02-02 13:30:10'',''2022-02-04 15:30:23''),[''2022-03-03 07:30:00'',''2022-05-04 15:30:00''],[''2022-08-10 13:00:00'',]}",
      tstz_multirange: "{[''2022-05-05 14:30:00+05'',''2022-06-06 13:30:00-03''),[''2022-07-01 13:30:00+05'',''2022-07-22 08:30:00-03''],[''2022-10-01 08:30:00-03'',]}",
      int4_multirange: "{[1,11),[500,700],[800,]}",
      int8_multirange: "{[10,100),[101,150],[200,]}",
    )

    insert_multirange(
      id: 202,
      date_multirange: "{[''2022-01-02'',''2022-01-04''],[''2022-07-10'',''2022-08-10''],[2022-08-01'',]}",
      num_multirange: "{[0.3,0.9],[1.3,4.4),[4.3,]}",
      ts_multirange: "{[''2022-02-02 13:30:10'',''2022-02-04 15:30:23''],[''2022-03-03 07:30:00'',''2022-05-04 15:30:00''],[''2022-05-03 13:00:00'',]}",
      tstz_multirange: "{[''2022-05-05 14:30:00+05'',''2022-06-06 13:30:00-03''],[''2022-07-01 13:30:00+05'',''2022-07-22 08:30:00-03''],[''2022-07-21 08:30:00-03'',]}",
      int4_multirange: "{[1,11],[500,700],[699,]}",
      int8_multirange: "{[10,100],[102,150],[149,]}",
    )

    insert_multirange(
      id: 203,
      date_multirange: "{[''2022-01-02'',''2022-01-04''],[,]}",
      num_multirange: "{[0.3,0.9],[,]}",
      ts_multirange: "{[''2022-02-02 13:30:10'',''2022-02-04 15:30:23''],[,]}",
      tstz_multirange: "{[''2022-05-05 14:30:00+05'',''2022-06-06 13:30:00-03''],[,]}",
      int4_multirange: "{[1,11],[,]}",
      int8_multirange: "{[10,100],[,]}"
    )

    @new_range = PostgresqlMultiRange.new
    @multi_range = PostgresqlMultiRange.find(201)
    @overlaping_ranges = PostgresqlMultiRange.find(202)
    @infinity_ranges = PostgresqlMultiRange.find(203)
  end

  teardown do
    @connection.drop_table "postgresql_multiranges", if_exists: true
    reset_connection
  end

  def test_data_type_of_range_types
    assert_equal :datemultirange, @multi_range.column_for_attribute(:date_multirange).type
    assert_equal :nummultirange, @multi_range.column_for_attribute(:num_multirange).type
    assert_equal :tsmultirange, @multi_range.column_for_attribute(:ts_multirange).type
    assert_equal :tstzmultirange, @multi_range.column_for_attribute(:tstz_multirange).type
    assert_equal :int4multirange, @multi_range.column_for_attribute(:int4_multirange).type
    assert_equal :int8multirange, @multi_range.column_for_attribute(:int8_multirange).type
  end

  def test_int4multirange_values
    assert_equal [1...11, 500...701, 800...::Float::INFINITY], @multi_range.int4_multirange
    assert_equal [1...12, 500...::Float::INFINITY], @overlaping_ranges.int4_multirange
    assert_equal [-::Float::INFINITY...::Float::INFINITY], @infinity_ranges.int4_multirange
  end

  def test_int8multirange_values
    assert_equal [10...100, 101...151, 200...::Float::INFINITY], @multi_range.int8_multirange
    assert_equal [10...101, 102...::Float::INFINITY], @overlaping_ranges.int8_multirange
    assert_equal [-::Float::INFINITY...::Float::INFINITY], @infinity_ranges.int8_multirange
  end

  def test_tsmultirange_values
    tz = ::ActiveRecord.default_timezone
    assert_equal [
      Time.public_send(tz, 2022, 2, 2, 13, 30, 10)...Time.public_send(tz, 2022, 2, 4, 15, 30, 23),
      Time.public_send(tz, 2022, 3, 3, 7, 30)..Time.public_send(tz, 2022, 5, 4, 15, 30),
      Time.public_send(tz, 2022, 8, 10, 13)...::Float::INFINITY
    ], @multi_range.ts_multirange
    assert_equal [
      Time.public_send(tz, 2022, 2, 2, 13, 30, 10)..Time.public_send(tz, 2022, 2, 4, 15, 30, 23),
      Time.public_send(tz, 2022, 3, 3, 7, 30)...::Float::INFINITY
    ], @overlaping_ranges.ts_multirange
    assert_equal [-::Float::INFINITY...::Float::INFINITY], @infinity_ranges.tstz_multirange
  end

  def test_tstzmultirange_values
    assert_equal [
      Time.parse("2022-05-05 09:30:00 UTC")...Time.parse("2022-06-06 16:30:00 UTC"),
      Time.parse("2022-07-01 08:30:00 UTC")..Time.parse("2022-07-22 11:30:00 UTC"),
      Time.parse("2022-10-01 11:30:00 UTC")...::Float::INFINITY
    ], @multi_range.tstz_multirange
    assert_equal [
      Time.parse("2022-05-05 09:30:00 UTC")..Time.parse("2022-06-06 16:30:00 UTC"),
      Time.parse("2022-07-01 08:30:00 UTC")...::Float::INFINITY
    ], @overlaping_ranges.tstz_multirange
    assert_equal [-::Float::INFINITY...::Float::INFINITY], @infinity_ranges.tstz_multirange
  end

  def test_nummultirange_values
    assert_equal [
      BigDecimal('-2.3')...BigDecimal('4.4'),
      BigDecimal('5.1')...BigDecimal('6.3'),
      BigDecimal('12.1')...::Float::INFINITY
    ], @multi_range.num_multirange
    assert_equal [
      BigDecimal('0.3')..BigDecimal('0.9'),
      BigDecimal('1.3')...::Float::INFINITY
    ], @overlaping_ranges.num_multirange
    assert_equal [-::Float::INFINITY...::Float::INFINITY], @infinity_ranges.num_multirange
  end

  def test_datemultirange_values
    assert_equal [
      Date.new(2022, 1, 2)...Date.new(2022, 1, 4),
      Date.new(2022, 7, 10)...Date.new(2022, 8, 11),
      Date.new(2022, 10, 1)...::Float::INFINITY
    ], @multi_range.date_multirange
    assert_equal [
      Date.new(2022, 1, 2)...Date.new(2022, 1, 5),
      Date.new(2022, 7, 10)...::Float::INFINITY
    ], @overlaping_ranges.date_multirange
    assert_equal [-::Float::INFINITY...::Float::INFINITY], @infinity_ranges.date_multirange
  end

  private
    def insert_multirange(values)
      @connection.execute <<~SQL
        INSERT INTO postgresql_multiranges (
        id,
        date_multirange,
        num_multirange,
        ts_multirange,
        tstz_multirange,
        int4_multirange,
        int8_multirange
        ) VALUES (
        #{values[:id]},
        '#{values[:date_multirange]}',
        '#{values[:num_multirange]}',
        '#{values[:ts_multirange]}',
        '#{values[:tstz_multirange]}',
        '#{values[:int4_multirange]}',
        '#{values[:int8_multirange]}'
      )
      SQL
    end
end
