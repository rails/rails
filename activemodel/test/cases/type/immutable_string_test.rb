# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class ImmutableStringTest < ActiveModel::TestCase
      test "cast strings are frozen" do
        s = "foo"
        type = Type::ImmutableString.new
        assert_equal true, type.cast(s).frozen?
      end

      test "immutable strings are not duped coming out" do
        s = "foo"
        type = Type::ImmutableString.new
        assert_same s, type.cast(s)
        assert_same s, type.deserialize(s)
      end

      test "custom true and false strings" do
        type = Type::ImmutableString.new(true: "aye", false: "nay")
        assert_equal "aye", type.cast(true)
        assert_equal "nay", type.cast(false)
        assert_equal "aye", type.serialize(true)
        assert_equal "nay", type.serialize(false)
      end

      test "booleans cast to their default string representations" do
        type = Type::ImmutableString.new
        assert_equal "t", type.cast(true)
        assert_equal "f", type.cast(false)
      end

      test "serialize coerces numerics and symbols to strings" do
        type = Type::ImmutableString.new
        assert_equal "123", type.serialize(123)
        assert_equal "sym", type.serialize(:sym)
      end
    end
  end
end
