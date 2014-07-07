require "cases/helper"

module ActiveRecord
  module Type
    class NumericTest < ActiveRecord::TestCase
      test "non-integer zero is not present" do
        assert_not Type::Float.new.value_present?(0.0)
        assert_not Type::Decimal.new.value_present?("0.0".to_d)
      end

      test "integer zero is not present" do
        assert_not Type::Integer.new.value_present?(0)
      end

      test "nil is not present" do
        assert_not Type::Integer.new.value_present?(nil)
      end

      test "non-zero is present" do
        assert Type::Integer.new.value_present?(1)
        assert Type::Float.new.value_present?(0.1)
        assert Type::Decimal.new.value_present?("0.1".to_d)
      end
    end
  end
end
