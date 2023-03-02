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

      test "leaves validly encoded strings untouched" do
        s = "string with àccénts".encode(Encoding::ISO_8859_1)
        type = Type::ImmutableString.new
        assert_same s, type.serialize(s)
      end

      test "serializes valid, binary-encoded strings to UTF-8" do
        s = "string with àccénts".b
        type = Type::ImmutableString.new
        serialized = type.serialize(s)
        assert_equal Encoding::UTF_8, serialized.encoding
        assert_equal s.bytes, serialized.bytes
      end

      test "leaves true binary data untouched" do
        binary_data = "\xEE\x49\xC7".b
        type = Type::ImmutableString.new
        assert_same binary_data, type.serialize(binary_data)
      end
    end
  end
end
