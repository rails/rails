require "cases/helper"
require "active_model/type"

module ActiveModel
  module Type
    class IntegerTest < ActiveModel::TestCase
      test "simple values" do
        type = Type::Integer.new
        assert_equal 1, type.cast(1)
        assert_equal 1, type.cast("1")
        assert_equal 1, type.cast("1ignore")
        assert_equal 0, type.cast("bad1")
        assert_equal 0, type.cast("bad")
        assert_equal 1, type.cast(1.7)
        assert_equal 0, type.cast(false)
        assert_equal 1, type.cast(true)
        assert_nil type.cast(nil)
      end

      test "random objects cast to nil" do
        type = Type::Integer.new
        assert_nil type.cast([1,2])
        assert_nil type.cast(1 => 2)
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

        assert type.changed?(5, 5, "5wibble")
        assert_not type.changed?(5, 5, "5")
        assert_not type.changed?(5, 5, "5.0")
        assert_not type.changed?(-5, -5, "-5")
        assert_not type.changed?(-5, -5, "-5.0")
        assert_not type.changed?(nil, nil, nil)
      end

      test "deprecated integer types" do
        assert_deprecated { Type::BigInteger.new }
        assert_deprecated { Type::UnsignedInteger.new }
      end
    end
  end
end
