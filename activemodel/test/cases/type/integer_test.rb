require "cases/helper"
require "active_model/type"

module ActiveModel
  module Type
    class IntegerTest < ActiveModel::TestCase
      test "simple values" do
        type = Type::Integer.new
        assert_equal 1, type.cast(1)
        assert_equal 1, type.cast('1')
        assert_equal 1, type.cast('1ignore')
        assert_equal 0, type.cast('bad1')
        assert_equal 0, type.cast('bad')
        assert_equal 1, type.cast(1.7)
        assert_equal 0, type.cast(false)
        assert_equal 1, type.cast(true)
        assert_nil type.cast(nil)
      end

      test "random objects cast to nil" do
        type = Type::Integer.new
        assert_nil type.cast([1,2])
        assert_nil type.cast({1 => 2})
        assert_nil type.cast(1..2)
      end

      test "casting objects without to_i" do
        type = Type::Integer.new
        assert_nil type.cast(::Object.new)
      end

      test "casting nan and infinity" do
        type = Type::Integer.new
        assert_nil type.cast(::Float::NAN)
        assert_nil type.cast(1.0/0.0)
      end

      test "casting booleans for database" do
        type = Type::Integer.new
        assert_equal 1, type.serialize(true)
        assert_equal 0, type.serialize(false)
      end

      test "changed?" do
        type = Type::Integer.new

        assert type.changed?(5, 5, '5wibble')
        assert_not type.changed?(5, 5, '5')
        assert_not type.changed?(5, 5, '5.0')
        assert_not type.changed?(-5, -5, '-5')
        assert_not type.changed?(-5, -5, '-5.0')
        assert_not type.changed?(nil, nil, nil)
      end

      test "values below int min value are out of range" do
        assert_raises(ActiveModel::RangeError) do
          Integer.new.serialize(-2147483649)
        end
      end

      test "values above int max value are out of range" do
        assert_raises(ActiveModel::RangeError) do
          Integer.new.serialize(2147483648)
        end
      end

      test "very small numbers are out of range" do
        assert_raises(ActiveModel::RangeError) do
          Integer.new.serialize(-9999999999999999999999999999999)
        end
      end

      test "very large numbers are out of range" do
        assert_raises(ActiveModel::RangeError) do
          Integer.new.serialize(9999999999999999999999999999999)
        end
      end

      test "normal numbers are in range" do
        type = Integer.new
        assert_equal(0, type.serialize(0))
        assert_equal(-1, type.serialize(-1))
        assert_equal(1, type.serialize(1))
      end

      test "int max value is in range" do
        assert_equal(2147483647, Integer.new.serialize(2147483647))
      end

      test "int min value is in range" do
        assert_equal(-2147483648, Integer.new.serialize(-2147483648))
      end

      test "columns with a larger limit have larger ranges" do
        type = Integer.new(limit: 8)

        assert_equal(9223372036854775807, type.serialize(9223372036854775807))
        assert_equal(-9223372036854775808, type.serialize(-9223372036854775808))
        assert_raises(ActiveModel::RangeError) do
          type.serialize(-9999999999999999999999999999999)
        end
        assert_raises(ActiveModel::RangeError) do
          type.serialize(9999999999999999999999999999999)
        end
      end
    end
  end
end
