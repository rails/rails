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
      date_multirange: "{[''2022-01-02'',''2022-01-04''],[''2022-07-10'',''2022-08-10'']}",
      num_multirange: "{[0.3,0.9],[-2.3,4.4]}",
      ts_multirange: "{[''2022-02-02 13:30:10'',''2022-02-04 15:30:23''],[''2022-03-03 07:30:00'',''2022-05-04 15:30:00'']}",
      tstz_multirange: "{[''2022-05-05 14:30:00+05'',''2022-06-06 13:30:00-03''],[''2022-07-01 13:30:00+05'',''2022-07-22 08:30:00-03'']}",
      int4_multirange: "{[1,10],[2,9]}",
      int8_multirange: "{[10,100],[101,150]}",
    )

    @first_range = PostgresqlMultiRange.find(201)
  end

  teardown do
    @connection.drop_table "postgresql_multiranges", if_exists: true
    reset_connection
  end

  def test_data_type_of_range_types
    assert_equal :datemultirange, @first_range.column_for_attribute(:date_multirange).type
    assert_equal :nummultirange, @first_range.column_for_attribute(:num_multirange).type
    assert_equal :tsmultirange, @first_range.column_for_attribute(:ts_multirange).type
    assert_equal :tstzmultirange, @first_range.column_for_attribute(:tstz_multirange).type
    assert_equal :int4multirange, @first_range.column_for_attribute(:int4_multirange).type
    assert_equal :int8multirange, @first_range.column_for_attribute(:int8_multirange).type
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
