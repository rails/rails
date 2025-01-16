# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class DateTimeTest < ActiveModel::TestCase
      def test_type_cast_datetime_and_timestamp
        type = Type::DateTime.new
        assert_nil type.cast(nil)
        assert_nil type.cast("")
        assert_nil type.cast("  ")
        assert_nil type.cast("ABC")
        assert_nil type.cast(" " * 129)

        datetime_string = ::Time.now.utc.strftime("%FT%T")
        assert_equal datetime_string, type.cast(datetime_string).strftime("%FT%T")
      end

      def test_string_to_time_with_timezone
        ["UTC", "US/Eastern"].each do |zone|
          with_timezone_config default: zone do
            type = Type::DateTime.new
            assert_equal ::Time.utc(2013, 9, 4, 0, 0, 0), type.cast("Wed, 04 Sep 2013 03:00:00 EAT")
          end
        end
      end

      def test_hash_to_time
        type = Type::DateTime.new
        assert_equal ::Time.utc(2018, 10, 15, 0, 0, 0), type.cast(1 => 2018, 2 => 10, 3 => 15)
      end

      def test_hash_with_wrong_keys
        type = Type::DateTime.new
        error = assert_raises(ArgumentError) { type.cast(a: 1) }
        assert_equal "Provided hash #{{ a: 1 }} doesn't contain necessary keys: [1, 2, 3]", error.message
      end

      test "serialize_cast_value is equivalent to serialize after cast" do
        type = Type::DateTime.new(precision: 1)
        value = type.cast("1999-12-31 12:34:56.789 -1000")

        assert_equal type.serialize(value), type.serialize_cast_value(value)
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
end
