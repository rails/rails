require "cases/helper"
require "models/company"

module ActiveRecord
  module Type
    class UnsignedIntegerTest < ActiveRecord::TestCase
      test "unsigned int max value is in range" do
        assert_equal(4294967295, UnsignedInteger.new.type_cast_from_user("4294967295"))
      end

      test "minus value is out of range" do
        assert_raises(::RangeError) do
          UnsignedInteger.new.type_cast_from_user("-1")
        end
      end
    end
  end
end
