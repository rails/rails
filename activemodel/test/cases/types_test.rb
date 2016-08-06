require "cases/helper"
require "active_model/type"
require "active_support/core_ext/numeric/time"

module ActiveModel
  class TypesTest < ActiveModel::TestCase
    def test_type_cast_boolean
      type = Type::Boolean.new
      assert type.cast("").nil?
      assert type.cast(nil).nil?

      assert type.cast(true)
      assert type.cast(1)
      assert type.cast("1")
      assert type.cast("t")
      assert type.cast("T")
      assert type.cast("true")
      assert type.cast("TRUE")
      assert type.cast("on")
      assert type.cast("ON")
      assert type.cast(" ")
      assert type.cast("\u3000\r\n")
      assert type.cast("\u0000")
      assert type.cast("SOMETHING RANDOM")

      # explicitly check for false vs nil
      assert_equal false, type.cast(false)
      assert_equal false, type.cast(0)
      assert_equal false, type.cast("0")
      assert_equal false, type.cast("f")
      assert_equal false, type.cast("F")
      assert_equal false, type.cast("false")
      assert_equal false, type.cast("FALSE")
      assert_equal false, type.cast("off")
      assert_equal false, type.cast("OFF")
    end

    def test_type_cast_float
      type = Type::Float.new
      assert_equal 1.0, type.cast("1")
    end

    def test_changing_float
      type = Type::Float.new

      assert type.changed?(5.0, 5.0, "5wibble")
      assert_not type.changed?(5.0, 5.0, "5")
      assert_not type.changed?(5.0, 5.0, "5.0")
      assert_not type.changed?(nil, nil, nil)
    end

    def test_type_cast_binary
      type = Type::Binary.new
      assert_equal nil, type.cast(nil)
      assert_equal "1", type.cast("1")
      assert_equal 1, type.cast(1)
    end

    def test_type_cast_time
      type = Type::Time.new
      assert_equal nil, type.cast(nil)
      assert_equal nil, type.cast("")
      assert_equal nil, type.cast("ABC")

      time_string = Time.now.utc.strftime("%T")
      assert_equal time_string, type.cast(time_string).strftime("%T")

      assert_equal ::Time.utc(2000,  1,  1, 16, 45, 54), type.cast("2015-06-13T19:45:54+03:00")
      assert_equal ::Time.utc(1999, 12, 31, 21,  7,  8), type.cast("06:07:08+09:00")
    end

    def test_type_cast_datetime_and_timestamp
      type = Type::DateTime.new
      assert_equal nil, type.cast(nil)
      assert_equal nil, type.cast("")
      assert_equal nil, type.cast("  ")
      assert_equal nil, type.cast("ABC")

      datetime_string = Time.now.utc.strftime("%FT%T")
      assert_equal datetime_string, type.cast(datetime_string).strftime("%FT%T")
    end

    def test_type_cast_date
      type = Type::Date.new
      assert_equal nil, type.cast(nil)
      assert_equal nil, type.cast("")
      assert_equal nil, type.cast(" ")
      assert_equal nil, type.cast("ABC")

      date_string = Time.now.utc.strftime("%F")
      assert_equal date_string, type.cast(date_string).strftime("%F")
    end

    def test_type_cast_duration_to_integer
      type = Type::Integer.new
      assert_equal 1800, type.cast(30.minutes)
      assert_equal 7200, type.cast(2.hours)
    end

    def test_string_to_time_with_timezone
      ["UTC", "US/Eastern"].each do |zone|
        with_timezone_config default: zone do
          type = Type::DateTime.new
          assert_equal Time.utc(2013, 9, 4, 0, 0, 0), type.cast("Wed, 04 Sep 2013 03:00:00 EAT")
        end
      end
    end

    def test_type_equality
      assert_equal Type::Value.new, Type::Value.new
      assert_not_equal Type::Value.new, Type::Integer.new
      assert_not_equal Type::Value.new(precision: 1), Type::Value.new(precision: 2)
    end

    private

    def with_timezone_config(default:)
      old_zone_default = ::Time.zone_default
      ::Time.zone_default = ::Time.find_zone(default)
      yield
    ensure
      ::Time.zone_default = old_zone_default
    end
  end
end
