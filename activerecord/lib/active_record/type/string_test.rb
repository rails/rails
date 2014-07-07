require "cases/helper"

module ActiveRecord
  module Type
    class StringTest < ActiveRecord::TestCase
      test "string 0 is present" do
        assert String.new.value_present?("0")
      end

      test "empty strings are not present" do
        assert_not String.new.value_present?("")
      end

      test "nil is not present" do
        assert_not String.new.value_present?(nil)
      end
    end
  end
end
