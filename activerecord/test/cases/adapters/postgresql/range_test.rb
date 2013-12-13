# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

if ActiveRecord::Base.connection.supports_ranges?
  class PostgresqlRange < ActiveRecord::Base
    self.table_name = "postgresql_ranges"
  end

  class PostgresqlRangeTest < ActiveRecord::TestCase
    def teardown
      @connection.execute 'DROP TABLE IF EXISTS postgresql_ranges'
    end

    def setup
      @connection = ActiveRecord::Base.connection
      begin
        @connection.transaction do
          @connection.create_table('json_data_type') do |t|
            t.daterange :date_range
            t.numrange :num_range
            t.tsrange :ts_range
            t.tstzrange :tstz_range
            t.int4range :int4_range
            t.int8range :int8_range
          end
        end
      rescue ActiveRecord::StatementInvalid
        return skip "do not test on PG without range"
      end

      @connection.execute <<-SQL
      INSERT INTO postgresql_ranges (
        id,
        date_range,
        num_range,
        ts_range,
        tstz_range,
        int4_range,
        int8_range
      ) VALUES (
        1,
        '[''2012-01-02'', ''2012-01-04'']',
        '[0.1, 0.2]',
        '[''2010-01-01 14:30'', ''2011-01-01 14:30'']',
        '[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'']',
        '[1, 10]',
        '[10, 100]'
      )
  SQL

      @connection.execute <<-SQL
      INSERT INTO postgresql_ranges (
        id,
        date_range,
        num_range,
        ts_range,
        tstz_range,
        int4_range,
        int8_range
      ) VALUES (
        2,
        '(''2012-01-02'', ''2012-01-04'')',
        '[0.1, 0.2)',
        '[''2010-01-01 14:30'', ''2011-01-01 14:30'')',
        '[''2010-01-01 14:30:00+05'', ''2011-01-01 14:30:00-03'')',
        '(1, 10)',
        '(10, 100)'
      )
  SQL

      @connection.execute <<-SQL
      INSERT INTO postgresql_ranges (
        id,
        date_range,
        num_range,
        ts_range,
        tstz_range,
        int4_range,
        int8_range
      ) VALUES (
        3,
        '(''2012-01-02'',]',
        '[0.1,]',
        '[''2010-01-01 14:30'',]',
        '[''2010-01-01 14:30:00+05'',]',
        '(1,]',
        '(10,]'
      )
  SQL

      @connection.execute <<-SQL
      INSERT INTO postgresql_ranges (
        id,
        date_range,
        num_range,
        ts_range,
        tstz_range,
        int4_range,
        int8_range
      ) VALUES (
        4,
        '[,]',
        '[,]',
        '[,]',
        '[,]',
        '[,]',
        '[,]'
      )
  SQL

      @connection.execute <<-SQL
      INSERT INTO postgresql_ranges (
        id,
        date_range,
        num_range,
        ts_range,
        tstz_range,
        int4_range,
        int8_range
      ) VALUES (
        5,
        '(''2012-01-02'', ''2012-01-02'')',
        '(0.1, 0.1)',
        '(''2010-01-01 14:30'', ''2010-01-01 14:30'')',
        '(''2010-01-01 14:30:00+05'', ''2010-01-01 06:30:00-03'')',
        '(1, 1)',
        '(10, 10)'
      )
  SQL

      @first_range = PostgresqlRange.find(1)
      @second_range = PostgresqlRange.find(2)
      @third_range = PostgresqlRange.find(3)
      @fourth_range = PostgresqlRange.find(4)
      @empty_range = PostgresqlRange.find(5)
    end

    def test_data_type_of_range_types
      assert_equal :daterange, @first_range.column_for_attribute(:date_range).type
      assert_equal :numrange, @first_range.column_for_attribute(:num_range).type
      assert_equal :tsrange, @first_range.column_for_attribute(:ts_range).type
      assert_equal :tstzrange, @first_range.column_for_attribute(:tstz_range).type
      assert_equal :int4range, @first_range.column_for_attribute(:int4_range).type
      assert_equal :int8range, @first_range.column_for_attribute(:int8_range).type
    end

    def test_int4range_values
      assert_equal 1...11, @first_range.int4_range
      assert_equal 2...10, @second_range.int4_range
      assert_equal 2...Float::INFINITY, @third_range.int4_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int4_range)
      assert_nil @empty_range.int4_range
    end

    def test_int8range_values
      assert_equal 10...101, @first_range.int8_range
      assert_equal 11...100, @second_range.int8_range
      assert_equal 11...Float::INFINITY, @third_range.int8_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.int8_range)
      assert_nil @empty_range.int8_range
    end

    def test_daterange_values
      assert_equal Date.new(2012, 1, 2)...Date.new(2012, 1, 5), @first_range.date_range
      assert_equal Date.new(2012, 1, 3)...Date.new(2012, 1, 4), @second_range.date_range
      assert_equal Date.new(2012, 1, 3)...Float::INFINITY, @third_range.date_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.date_range)
      assert_nil @empty_range.date_range
    end

    def test_numrange_values
      assert_equal BigDecimal.new('0.1')..BigDecimal.new('0.2'), @first_range.num_range
      assert_equal BigDecimal.new('0.1')...BigDecimal.new('0.2'), @second_range.num_range
      assert_equal BigDecimal.new('0.1')...BigDecimal.new('Infinity'), @third_range.num_range
      assert_equal BigDecimal.new('-Infinity')...BigDecimal.new('Infinity'), @fourth_range.num_range
      assert_nil @empty_range.num_range
    end

    def test_tsrange_values
      tz = ::ActiveRecord::Base.default_timezone
      assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)..Time.send(tz, 2011, 1, 1, 14, 30, 0), @first_range.ts_range
      assert_equal Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 1, 1, 14, 30, 0), @second_range.ts_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.ts_range)
      assert_nil @empty_range.ts_range
    end

    def test_tstzrange_values
      assert_equal Time.parse('2010-01-01 09:30:00 UTC')..Time.parse('2011-01-01 17:30:00 UTC'), @first_range.tstz_range
      assert_equal Time.parse('2010-01-01 09:30:00 UTC')...Time.parse('2011-01-01 17:30:00 UTC'), @second_range.tstz_range
      assert_equal(-Float::INFINITY...Float::INFINITY, @fourth_range.tstz_range)
      assert_nil @empty_range.tstz_range
    end

    def test_create_tstzrange
      tstzrange = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2011-02-02 14:30:00 CDT')
      range = PostgresqlRange.new(:tstz_range => tstzrange)
      assert range.save
      assert range.reload
      assert_equal range.tstz_range, tstzrange
      assert_equal range.tstz_range, Time.parse('2010-01-01 13:30:00 UTC')...Time.parse('2011-02-02 19:30:00 UTC')
    end

    def test_update_tstzrange
      new_tstzrange = Time.parse('2010-01-01 14:30:00 CDT')...Time.parse('2011-02-02 14:30:00 CET')
      @first_range.tstz_range = new_tstzrange
      assert @first_range.save
      assert @first_range.reload
      assert_equal new_tstzrange, @first_range.tstz_range
      @first_range.tstz_range = Time.parse('2010-01-01 14:30:00 +0100')...Time.parse('2010-01-01 13:30:00 +0000')
      assert @first_range.save
      assert @first_range.reload
      assert_nil @first_range.tstz_range
    end

    def test_create_tsrange
      tz = ::ActiveRecord::Base.default_timezone
      tsrange = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0)
      range = PostgresqlRange.new(:ts_range => tsrange)
      assert range.save
      assert range.reload
      assert_equal range.ts_range, tsrange
    end

    def test_update_tsrange
      tz = ::ActiveRecord::Base.default_timezone
      new_tsrange = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2011, 2, 2, 14, 30, 0)
      @first_range.ts_range = new_tsrange
      assert @first_range.save
      assert @first_range.reload
      assert_equal new_tsrange, @first_range.ts_range
      @first_range.ts_range = Time.send(tz, 2010, 1, 1, 14, 30, 0)...Time.send(tz, 2010, 1, 1, 14, 30, 0)
      assert @first_range.save
      assert @first_range.reload
      assert_nil @first_range.ts_range
    end

    def test_create_numrange
      numrange = BigDecimal.new('0.5')...BigDecimal.new('1')
      range = PostgresqlRange.new(:num_range => numrange)
      assert range.save
      assert range.reload
      assert_equal range.num_range, numrange
    end

    def test_update_numrange
      new_numrange = BigDecimal.new('0.5')...BigDecimal.new('1')
      @first_range.num_range = new_numrange
      assert @first_range.save
      assert @first_range.reload
      assert_equal new_numrange, @first_range.num_range
      @first_range.num_range = BigDecimal.new('0.5')...BigDecimal.new('0.5')
      assert @first_range.save
      assert @first_range.reload
      assert_nil @first_range.num_range
    end

    def test_create_daterange
      daterange = Range.new(Date.new(2012, 1, 1), Date.new(2013, 1, 1), true)
      range = PostgresqlRange.new(:date_range => daterange)
      assert range.save
      assert range.reload
      assert_equal range.date_range, daterange
    end

    def test_update_daterange
      new_daterange = Date.new(2012, 2, 3)...Date.new(2012, 2, 10)
      @first_range.date_range = new_daterange
      assert @first_range.save
      assert @first_range.reload
      assert_equal new_daterange, @first_range.date_range
      @first_range.date_range = Date.new(2012, 2, 3)...Date.new(2012, 2, 3)
      assert @first_range.save
      assert @first_range.reload
      assert_nil @first_range.date_range
    end

    def test_create_int4range
      int4range = Range.new(3, 50, true)
      range = PostgresqlRange.new(:int4_range => int4range)
      assert range.save
      assert range.reload
      assert_equal range.int4_range, int4range
    end

    def test_update_int4range
      new_int4range = 6...10
      @first_range.int4_range = new_int4range
      assert @first_range.save
      assert @first_range.reload
      assert_equal new_int4range, @first_range.int4_range
      @first_range.int4_range = 3...3
      assert @first_range.save
      assert @first_range.reload
      assert_nil @first_range.int4_range
    end

    def test_create_int8range
      int8range = Range.new(30, 50, true)
      range = PostgresqlRange.new(:int8_range => int8range)
      assert range.save
      assert range.reload
      assert_equal range.int8_range, int8range
    end

    def test_update_int8range
      new_int8range = 60000...10000000
      @first_range.int8_range = new_int8range
      assert @first_range.save
      assert @first_range.reload
      assert_equal new_int8range, @first_range.int8_range
      @first_range.int8_range = 39999...39999
      assert @first_range.save
      assert @first_range.reload
      assert_nil @first_range.int8_range
    end
  end
end
