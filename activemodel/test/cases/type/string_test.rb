require "cases/helper"
require "active_model/type"

module ActiveModel
  class StringTypeTest < ActiveModel::TestCase
    test "type casting" do
      type = Type::String.new
      assert_equal "t", type.cast(true)
      assert_equal "f", type.cast(false)
      assert_equal "123", type.cast(123)
    end

    test "immutable strings are not duped coming out" do
      s = "foo"
      type = Type::ImmutableString.new
      assert_same s, type.cast(s)
      assert_same s, type.deserialize(s)
    end

    test "values are duped coming out" do
      s = "foo"
      type = Type::String.new
      assert_not_same s, type.cast(s)
      assert_not_same s, type.deserialize(s)
    end
  end
end
