require "cases/helper"

module ActiveRecord
  module Type
    class DecimalTest < ActiveRecord::TestCase
      def test_type_cast_decimal
        type = Decimal.new
        assert_equal BigDecimal.new("0"), type.type_cast_from_user(BigDecimal.new("0"))
        assert_equal BigDecimal.new("123"), type.type_cast_from_user(123.0)
        assert_equal BigDecimal.new("1"), type.type_cast_from_user(:"1")
      end

      def test_type_cast_decimal_from_float_with_large_precision
        type = Decimal.new(precision: ::Float::DIG + 2)
        assert_equal BigDecimal.new("123.0"), type.type_cast_from_user(123.0)
      end

      def test_type_cast_from_float_with_unspecified_precision
        type = Decimal.new
        assert_equal 22.68.to_d, type.type_cast_from_user(22.68)
      end

      def test_type_cast_decimal_from_rational_with_precision
        type = Decimal.new(precision: 2)
        assert_equal BigDecimal("0.33"), type.type_cast_from_user(Rational(1, 3))
      end

      def test_type_cast_decimal_from_rational_with_precision_and_scale
        type = Decimal.new(precision: 4, scale: 2)
        assert_equal BigDecimal("0.33"), type.type_cast_from_user(Rational(1, 3))
      end

      def test_type_cast_decimal_from_rational_without_precision_defaults_to_18_36
        type = Decimal.new
        assert_equal BigDecimal("0.333333333333333333E0"), type.type_cast_from_user(Rational(1, 3))
      end

      def test_type_cast_decimal_from_object_responding_to_d
        value = Object.new
        def value.to_d
          BigDecimal.new("1")
        end
        type = Decimal.new
        assert_equal BigDecimal("1"), type.type_cast_from_user(value)
      end

      def test_changed?
        type = Decimal.new

        assert type.changed?(5.0, 5.0, '5.0wibble')
        assert_not type.changed?(5.0, 5.0, '5.0')
        assert_not type.changed?(-5.0, -5.0, '-5.0')
      end
    end
  end
end
