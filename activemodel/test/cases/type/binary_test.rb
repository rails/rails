# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BinaryTest < ActiveModel::TestCase
      def test_type_cast_binary
        type = Type::Binary.new

        assert_nil type.cast(nil)
        assert_equal 1, type.cast(1)

        assert_equal "1", type.cast("1")
        assert_equal Encoding::BINARY, type.cast("1").encoding

        assert_equal "ƒée".b, type.cast("ƒée")
        assert_not_equal "ƒée", type.cast("ƒée")
      end

      def test_serialize_binary_strings
        type = Type::Binary.new
        assert_equal "ƒée".b, type.serialize("ƒée")
        assert_not_equal "ƒée", type.serialize("ƒée")
      end
    end
  end
end
