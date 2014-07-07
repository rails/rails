require "cases/helper"

module ActiveRecord
  module Type
    class ValueTest < ActiveRecord::TestCase
      test "true is present" do
        assert Value.new.value_present?(true)
      end

      test "false is not present" do
        assert_not Value.new.value_present?(false)
      end

      test "nil is not present" do
        assert_not Value.new.value_present?(nil)
      end

      test "blank values are not present" do
        assert_not Value.new.value_present?("")
      end

      test "'false' values are not present" do
        ConnectionAdapters::Column::FALSE_VALUES.each do |value|
          assert_not Value.new.value_present?(value), "#{value.inspect} should not be present"
        end
      end
    end
  end
end
