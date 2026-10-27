# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class DecimalTest < ActiveModel::TestCase
      def test_type_cast_decimal
        type = Decimal.new
        assert_equal BigDecimal("0"), type.cast(BigDecimal("0"))
        assert_equal BigDecimal("123"), type.cast(123.0)
        assert_equal BigDecimal("1"), type.cast(:"1")
      end

      def test_type_cast_decimal_from_invalid_string
        type = Decimal.new
        assert_nil type.cast("")
        assert_equal BigDecimal("1"), type.cast("1ignore")
        assert_equal BigDecimal("0"), type.cast("bad1")
        assert_equal BigDecimal("0"), type.cast("bad")
      end

      def test_type_cast_decimal_from_float_with_large_precision
        type = Decimal.new(precision: ::Float::DIG + 2)
        assert_equal BigDecimal("123.0"), type.cast(123.0)
      end

      def test_type_cast_from_float_with_unspecified_precision
        type = Decimal.new
        assert_equal 22.68.to_d, type.cast(22.68)
      end

      def test_type_cast_decimal_from_rational_with_precision
        type = Decimal.new(precision: 2)
        assert_equal BigDecimal("0.33"), type.cast(Rational(1, 3))
        assert_equal BigDecimal("0.67"), type.cast(Rational(2, 3))
      end

      def test_type_cast_decimal_from_rational_with_precision_and_scale
        type = Decimal.new(precision: 4, scale: 2)
        assert_equal BigDecimal("0.33"), type.cast(Rational(1, 3))
        assert_equal BigDecimal("0.67"), type.cast(Rational(2, 3))
      end

      def test_type_cast_decimal_from_rational_without_precision_defaults_to_18_36
        type = Decimal.new
        assert_equal BigDecimal("0.333333333333333333E0"), type.cast(Rational(1, 3))
        assert_equal BigDecimal("0.666666666666666667E0"), type.cast(Rational(2, 3))
      end

      def test_type_cast_decimal_from_object_responding_to_d
        value = Object.new
        def value.to_d
          BigDecimal("1")
        end
        type = Decimal.new
        assert_equal BigDecimal("1"), type.cast(value)
      end

      def test_type_cast_big_decimal_within_scale_returns_it_as_is
        value = BigDecimal("1234.5")

        assert_same value, Decimal.new.cast(value)
        assert_same value, Decimal.new(precision: 10, scale: 2).cast(value)
        assert_same value, Decimal.new(precision: 10, scale: 1).cast(value)
      end

      def test_type_cast_big_decimal_beyond_scale_rounds_it
        type = Decimal.new(precision: 10, scale: 2)

        assert_equal BigDecimal("1234.57"), type.cast(BigDecimal("1234.567"))
      end

      def test_type_cast_big_decimal_with_zero_or_negative_scale_rounds_it_to_an_integer
        assert_equal 1234, Decimal.new(scale: 0).cast(BigDecimal("1234"))
        assert_equal 1200, Decimal.new(scale: -2).cast(BigDecimal("1234.5"))
        assert_kind_of ::Integer, Decimal.new(scale: 0).cast(BigDecimal("1234"))
      end

      def test_changed?
        type = Decimal.new

        assert type.changed?(0.0, 0, "wibble")
        assert type.changed?(5.0, 0, "wibble")
        assert_not type.changed?(5.0, 5.0, "5.0wibble")
        assert_not type.changed?(5.0, 5.0, "5.0")
        assert_not type.changed?(-5.0, -5.0, "-5.0")
        assert_not type.changed?(5.0, 5.0, "0.5e+1")
        assert_not type.changed?(BigDecimal("0.0") / 0, BigDecimal("0.0") / 0, BigDecimal("0.0") / 0)
        assert type.changed?(BigDecimal("0.0") / 0, 0.0 / 0.0, 0.0 / 0.0)
      end

      def test_scale_is_applied_before_precision_to_prevent_rounding_errors
        type = Decimal.new(precision: 5, scale: 3)

        assert_equal BigDecimal("1.250"), type.cast(1.250473853637869)
        assert_equal BigDecimal("1.250"), type.cast("1.250473853637869")
      end
    end
  end
end
