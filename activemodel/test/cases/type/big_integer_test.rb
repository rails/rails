# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BigIntegerTest < ActiveModel::TestCase
      def test_type_cast_big_integer
        type = Type::BigInteger.new
        assert_equal 1, type.cast(1)
        assert_equal 1, type.cast("1")
      end

      test "long numeric strings are cast without truncation" do
        type = Type::BigInteger.new
        assert_equal 18446744073709551615, type.cast("18446744073709551615")
        assert_equal(-9999999999999999999999999999999, type.cast("-9999999999999999999999999999999"))
      end

      test "long strings are truncated to twice the precision before being cast" do
        type = Type::BigInteger.new(precision: 20)
        assert_equal 18446744073709551615, type.cast("18446744073709551615")
        assert_equal ("1" * 40).to_i, type.cast("1" * 41)
      end

      test "very long strings are truncated before being cast without a precision" do
        type = Type::BigInteger.new
        assert_equal ("9" * 2000).to_i, type.cast("9" * 5000)
      end

      def test_small_values
        type = Type::BigInteger.new
        assert_equal(-9999999999999999999999999999999, type.serialize(-9999999999999999999999999999999))
      end

      def test_large_values
        type = Type::BigInteger.new
        assert_equal 9999999999999999999999999999999, type.serialize(9999999999999999999999999999999)
      end

      test "serialize_cast_value is equivalent to serialize after cast" do
        type = Type::BigInteger.new
        value = type.cast(9999999999999999999999999999999)

        assert_equal type.serialize(value), type.serialize_cast_value(value)
        assert_equal type.serialize(-value), type.serialize_cast_value(-value)
      end
    end
  end
end
