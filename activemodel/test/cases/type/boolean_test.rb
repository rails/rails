require "cases/helper"
require "active_model/type"

module ActiveModel
  module Type
    class BooleanTest < ActiveModel::TestCase
      def test_type_cast_boolean
        type = Type::Boolean.new
        assert type.cast("").nil?
        assert type.cast(nil).nil?

        # explicitly check for true
        assert_equal true, type.cast(true)
        assert_equal true, type.cast(1)
        assert_equal true, type.cast("1")
        assert_equal true, type.cast("t")
        assert_equal true, type.cast("T")
        assert_equal true, type.cast("true")
        assert_equal true, type.cast("TRUE")
        assert_equal true, type.cast("on")
        assert_equal true, type.cast("ON")
        assert_equal true, type.cast(" ")
        assert_equal true, type.cast("\u3000\r\n")
        assert_equal true, type.cast("\u0000")
        assert_equal true, type.cast("SOMETHING RANDOM")

        # explicitly check for false vs nil
        assert_equal false, type.cast(false)
        assert_equal false, type.cast(0)
        assert_equal false, type.cast("0")
        assert_equal false, type.cast("f")
        assert_equal false, type.cast("F")
        assert_equal false, type.cast("false")
        assert_equal false, type.cast("FALSE")
        assert_equal false, type.cast("off")
        assert_equal false, type.cast("OFF")
      end

      def test_serialize_boolean
        type = Type::Boolean.new
        assert type.serialize("").nil?
        assert type.serialize(nil).nil?

        # explicitly check for true
        assert_equal true, type.serialize(true)
        assert_equal true, type.serialize(1)
        assert_equal true, type.serialize("1")
        assert_equal true, type.serialize("t")
        assert_equal true, type.serialize("T")
        assert_equal true, type.serialize("true")
        assert_equal true, type.serialize("TRUE")
        assert_equal true, type.serialize("on")
        assert_equal true, type.serialize("ON")
        assert_equal true, type.serialize(" ")
        assert_equal true, type.serialize("\u3000\r\n")
        assert_equal true, type.serialize("\u0000")
        assert_equal true, type.serialize("SOMETHING RANDOM")

        # explicitly check for false vs nil
        assert_equal false, type.serialize(false)
        assert_equal false, type.serialize(0)
        assert_equal false, type.serialize("0")
        assert_equal false, type.serialize("f")
        assert_equal false, type.serialize("F")
        assert_equal false, type.serialize("false")
        assert_equal false, type.serialize("FALSE")
        assert_equal false, type.serialize("off")
        assert_equal false, type.serialize("OFF")
      end
    end
  end
end
