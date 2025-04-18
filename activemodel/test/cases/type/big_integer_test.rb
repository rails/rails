# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BigIntegerTest < ActiveModel::TestCase
      class CustomNumber
        attr_reader :num

        def initialize(num)
          @num = num
        end

        alias_method :to_i, :num
      end

      def test_type_cast_big_integer
        type = Type::BigInteger.new
        assert_equal 1, type.cast(1)
        assert_equal 1, type.cast("1")
      end

      def test_small_values
        type = Type::BigInteger.new
        assert_equal(-9999999999999999999999999999999, type.serialize(-9999999999999999999999999999999))
      end

      def test_large_values
        type = Type::BigInteger.new
        assert_equal 9999999999999999999999999999999, type.serialize(9999999999999999999999999999999)
      end

      def test_integer_like_classes_that_are_greater_than_4_bytes_still_serialize
        type = Type::BigInteger.new
        large_number = 9999999999999999999999999999999

        assert_equal large_number, type.serialize(CustomNumber.new(large_number))
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
