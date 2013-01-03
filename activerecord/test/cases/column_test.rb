require "cases/helper"
require 'models/company'

module ActiveRecord
  module ConnectionAdapters
    class ColumnTest < ActiveRecord::TestCase
      def test_type_cast_boolean
        column = Column.new("field", nil, "boolean")
        assert column.type_cast(true)
        assert column.type_cast(1)
        assert column.type_cast('1')
        assert column.type_cast('t')
        assert column.type_cast('T')
        assert column.type_cast('true')
        assert column.type_cast('TRUE')
        assert column.type_cast('on')
        assert column.type_cast('ON')
        assert !column.type_cast(false)
        assert !column.type_cast(0)
        assert !column.type_cast('0')
        assert !column.type_cast('f')
        assert !column.type_cast('F')
        assert !column.type_cast('false')
        assert !column.type_cast('FALSE')
        assert !column.type_cast('off')
        assert !column.type_cast('OFF')
      end

      def test_type_cast_integer
        column = Column.new("field", nil, "integer")
        assert_equal 1, column.type_cast(1)
        assert_equal 1, column.type_cast('1')
        assert_equal 1, column.type_cast('1ignore')
        assert_equal 0, column.type_cast('bad1')
        assert_equal 0, column.type_cast('bad')
        assert_equal 1, column.type_cast(1.7)
        assert_equal 0, column.type_cast(false)
        assert_equal 1, column.type_cast(true)
        assert_nil column.type_cast(nil)
      end

      def test_type_cast_non_integer_to_integer
        column = Column.new("field", nil, "integer")
        assert_nil column.type_cast([1,2])
        assert_nil column.type_cast({1 => 2})
        assert_nil column.type_cast((1..2))
      end

      def test_type_cast_activerecord_to_integer
        column = Column.new("field", nil, "integer")
        firm = Firm.create(:name => 'Apple')
        assert_nil column.type_cast(firm)
      end

      def test_type_cast_object_without_to_i_to_integer
        column = Column.new("field", nil, "integer")
        assert_nil column.type_cast(Object.new)
      end

      def test_type_cast_time
        column = Column.new("field", nil, "time")
        assert_equal nil, column.type_cast('')
        assert_equal nil, column.type_cast('  ')

        time_string = Time.now.utc.strftime("%T")
        assert_equal time_string, column.type_cast(time_string).strftime("%T")
      end

      def test_type_cast_datetime_and_timestamp
        [Column.new("field", nil, "datetime"), Column.new("field", nil, "timestamp")].each do |column|
          assert_equal nil, column.type_cast('')
          assert_equal nil, column.type_cast('  ')

          datetime_string = Time.now.utc.strftime("%FT%T")
          assert_equal datetime_string, column.type_cast(datetime_string).strftime("%FT%T")
        end
      end

      def test_type_cast_date
        column = Column.new("field", nil, "date")
        assert_equal nil, column.type_cast('')
        assert_equal nil, column.type_cast('  ')

        date_string = Time.now.utc.strftime("%F")
        assert_equal date_string, column.type_cast(date_string).strftime("%F")
      end

      def test_type_cast_duration_to_integer
        column = Column.new("field", nil, "integer")
        assert_equal 1800, column.type_cast(30.minutes)
        assert_equal 7200, column.type_cast(2.hours)
      end
    end
  end
end
