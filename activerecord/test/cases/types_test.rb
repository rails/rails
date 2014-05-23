require "cases/helper"
require 'models/company'

module ActiveRecord
  module ConnectionAdapters
    class TypesTest < ActiveRecord::TestCase
      def test_type_cast_boolean
        type = Type::Boolean.new
        assert type.type_cast('').nil?
        assert type.type_cast(nil).nil?

        assert type.type_cast(true)
        assert type.type_cast(1)
        assert type.type_cast('1')
        assert type.type_cast('t')
        assert type.type_cast('T')
        assert type.type_cast('true')
        assert type.type_cast('TRUE')
        assert type.type_cast('on')
        assert type.type_cast('ON')

        # explicitly check for false vs nil
        assert_equal false, type.type_cast(false)
        assert_equal false, type.type_cast(0)
        assert_equal false, type.type_cast('0')
        assert_equal false, type.type_cast('f')
        assert_equal false, type.type_cast('F')
        assert_equal false, type.type_cast('false')
        assert_equal false, type.type_cast('FALSE')
        assert_equal false, type.type_cast('off')
        assert_equal false, type.type_cast('OFF')
        assert_equal false, type.type_cast(' ')
        assert_equal false, type.type_cast("\u3000\r\n")
        assert_equal false, type.type_cast("\u0000")
        assert_equal false, type.type_cast('SOMETHING RANDOM')
      end

      def test_type_cast_string
        type = Type::String.new
        assert_equal "1", type.type_cast(true)
        assert_equal "0", type.type_cast(false)
        assert_equal "123", type.type_cast(123)
      end

      def test_type_cast_integer
        type = Type::Integer.new
        assert_equal 1, type.type_cast(1)
        assert_equal 1, type.type_cast('1')
        assert_equal 1, type.type_cast('1ignore')
        assert_equal 0, type.type_cast('bad1')
        assert_equal 0, type.type_cast('bad')
        assert_equal 1, type.type_cast(1.7)
        assert_equal 0, type.type_cast(false)
        assert_equal 1, type.type_cast(true)
        assert_nil type.type_cast(nil)
      end

      def test_type_cast_non_integer_to_integer
        type = Type::Integer.new
        assert_nil type.type_cast([1,2])
        assert_nil type.type_cast({1 => 2})
        assert_nil type.type_cast((1..2))
      end

      def test_type_cast_activerecord_to_integer
        type = Type::Integer.new
        firm = Firm.create(:name => 'Apple')
        assert_nil type.type_cast(firm)
      end

      def test_type_cast_object_without_to_i_to_integer
        type = Type::Integer.new
        assert_nil type.type_cast(Object.new)
      end

      def test_type_cast_nan_and_infinity_to_integer
        type = Type::Integer.new
        assert_nil type.type_cast(Float::NAN)
        assert_nil type.type_cast(1.0/0.0)
      end

      def test_type_cast_float
        type = Type::Float.new
        assert_equal 1.0, type.type_cast("1")
      end

      def test_type_cast_decimal
        type = Type::Decimal.new
        assert_equal BigDecimal.new("0"), type.type_cast(BigDecimal.new("0"))
        assert_equal BigDecimal.new("123"), type.type_cast(123.0)
        assert_equal BigDecimal.new("1"), type.type_cast(:"1")
      end

      def test_type_cast_binary
        type = Type::Binary.new
        assert_equal nil, type.type_cast(nil)
        assert_equal "1", type.type_cast("1")
        assert_equal 1, type.type_cast(1)
      end

      def test_type_cast_time
        type = Type::Time.new
        assert_equal nil, type.type_cast(nil)
        assert_equal nil, type.type_cast('')
        assert_equal nil, type.type_cast('ABC')

        time_string = Time.now.utc.strftime("%T")
        assert_equal time_string, type.type_cast(time_string).strftime("%T")
      end

      def test_type_cast_datetime_and_timestamp
        type = Type::DateTime.new
        assert_equal nil, type.type_cast(nil)
        assert_equal nil, type.type_cast('')
        assert_equal nil, type.type_cast('  ')
        assert_equal nil, type.type_cast('ABC')

        datetime_string = Time.now.utc.strftime("%FT%T")
        assert_equal datetime_string, type.type_cast(datetime_string).strftime("%FT%T")
      end

      def test_type_cast_date
        type = Type::Date.new
        assert_equal nil, type.type_cast(nil)
        assert_equal nil, type.type_cast('')
        assert_equal nil, type.type_cast(' ')
        assert_equal nil, type.type_cast('ABC')

        date_string = Time.now.utc.strftime("%F")
        assert_equal date_string, type.type_cast(date_string).strftime("%F")
      end

      def test_type_cast_duration_to_integer
        type = Type::Integer.new
        assert_equal 1800, type.type_cast(30.minutes)
        assert_equal 7200, type.type_cast(2.hours)
      end

      def test_string_to_time_with_timezone
        [:utc, :local].each do |zone|
          with_timezone_config default: zone do
            type = Type::DateTime.new
            assert_equal Time.utc(2013, 9, 4, 0, 0, 0), type.type_cast("Wed, 04 Sep 2013 03:00:00 EAT")
          end
        end
      end

      if current_adapter?(:SQLite3Adapter)
        def test_binary_encoding
          type = SQLite3Binary.new
          utf8_string = "a string".encode(Encoding::UTF_8)
          type_cast = type.type_cast(utf8_string)

          assert_equal Encoding::ASCII_8BIT, type_cast.encoding
        end
      end
    end
  end
end
