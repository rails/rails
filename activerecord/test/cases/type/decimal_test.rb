require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class DecimalTest < ActiveRecord::TestCase
      def test_type_cast_decimal
        type = Type::Decimal.new
        assert_equal BigDecimal.new("0"), type.type_cast_from_user(BigDecimal.new("0"))
        assert_equal BigDecimal.new("123"), type.type_cast_from_user(123.0)
        assert_equal BigDecimal.new("1"), type.type_cast_from_user(:"1")
      end

      def test_type_cast_rational_to_decimal_with_precision
        type = Type::Decimal.new(precision: 2)
        assert_equal BigDecimal("0.33"), type.type_cast_from_user(Rational(1, 3))
      end

      def test_type_cast_rational_to_decimal_without_precision_defaults_to_18_36
        type = Type::Decimal.new
        assert_equal BigDecimal("0.333333333333333333E0"), type.type_cast_from_user(Rational(1, 3))
      end
    end
  end
end
