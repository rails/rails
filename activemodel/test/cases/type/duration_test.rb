# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class DurationTest < ActiveModel::TestCase
      def test_type_cast_from_integer
        type = Duration.new

        assert type.cast(123).is_a?(ActiveSupport::Duration)

        assert_equal 0.seconds, type.cast(0)
        assert_equal 123.seconds, type.cast(123)
        assert_equal (-123.seconds), type.cast(-123)
      end

      def test_type_cast_from_decimal
        type = Duration.new

        assert type.cast(123.0).is_a?(ActiveSupport::Duration)

        assert_equal 0.0.seconds, type.cast(0.0)
        assert_equal 123.0.seconds, type.cast(123.0)
        assert_equal (-123.seconds), type.cast(-123.0)
      end

      def test_type_cast_from_from_string
        type = Duration.new

        assert_equal 1.year + 2.minutes, type.cast("P1YT2M")
        assert_equal 10.hours, type.cast("PT10H")
        assert_equal 1.day + 1.hour, type.cast("P1DT1H")
      end

      def test_type_cast_from_invalid_string
        type = Duration.new
        assert_nil type.cast("")
        assert_nil type.cast("1ignore")
        assert_nil type.cast("1 year 2 minutes")
        assert_nil type.cast("PTbad")
      end

      def test_type_serialize_duration_with_large_precision
        type = Duration.new(precision: ::Float::DIG + 2)

        assert_equal (1.year + 2.minutes + 5.7777.seconds).iso8601(precision: ::Float::DIG + 2), type.serialize(1.year + 2.minutes + 5.7777.seconds)
      end

      def test_type_serialize_duration_with_precision
        type = Duration.new(precision: 2)

        assert_equal (1.year + 2.minutes + 5.7777.seconds).iso8601(precision: 2), type.serialize(1.year + 2.minutes + 5.7777.seconds)
      end

      def test_changed?
        type = Duration.new

        assert type.changed?(0.1.seconds, 0.seconds, 0)
        assert type.changed?(123.seconds, -123.seconds, -123)
        assert type.changed?(1.year + 3.minutes, 1.year + 2.minutes, "P1YT2M")
        assert_not type.changed?(1.year + 2.minutes, 1.year + 2.minutes, "P1YT2M")
        assert_not type.changed?(3.hours / 2, 3.hours / 2, 3.hours / 2)
        assert_not type.changed?(3.hours / 2, 3.0.hours / 2.0, 3.0.hours / 2.0)
        assert type.changed?(3.hours / 2, 3.0.hours / 1, 3.0.hours / 1)
      end
    end
  end
end
