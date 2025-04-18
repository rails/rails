# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module Type
    class UnsignedIntegerTest < ActiveRecord::TestCase
      test "unsigned int max value is in range" do
        assert_equal(4294967295, UnsignedInteger.new.serialize(4294967295))
      end

      test "minus value is out of range" do
        assert_raises(ActiveModel::RangeError) do
          UnsignedInteger.new.serialize(-1)
        end
      end

      test "serialize_cast_value enforces range" do
        type = UnsignedInteger.new

        assert_raises(ActiveModel::RangeError) do
          type.serialize_cast_value(-1)
        end

        assert_raises(ActiveModel::RangeError) do
          type.serialize_cast_value(4294967296)
        end
      end
    end
  end
end
