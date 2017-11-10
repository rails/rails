# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BinaryTest < ActiveModel::TestCase
      def test_type_cast_binary
        type = Type::Binary.new
        assert_nil type.cast(nil)
        assert_equal "1", type.cast("1")
        assert_equal 1, type.cast(1)
      end
    end
  end
end
