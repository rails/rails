# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BooleanTest < ActiveModel::TestCase
      def test_type_cast_boolean
        type = Type::Boolean.new
        assert_nil type.cast("")
        assert_nil type.cast(nil)

        assert type.cast(true)
        assert type.cast(1)
        assert type.cast("1")
        assert type.cast("t")
        assert type.cast("T")
        assert type.cast("true")
        assert type.cast("TRUE")
        assert type.cast("on")
        assert type.cast("ON")
        assert type.cast(" ")
        assert type.cast("\u3000\r\n")
        assert type.cast("\u0000")
        assert type.cast("SOMETHING RANDOM")
        assert type.cast(:"1")
        assert type.cast(:t)
        assert type.cast(:T)
        assert type.cast(:true)
        assert type.cast(:TRUE)
        assert type.cast(:on)
        assert type.cast(:ON)

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
        assert_equal false, type.cast(:"0")
        assert_equal false, type.cast(:f)
        assert_equal false, type.cast(:F)
        assert_equal false, type.cast(:false)
        assert_equal false, type.cast(:FALSE)
        assert_equal false, type.cast(:off)
        assert_equal false, type.cast(:OFF)
      end
    end
  end
end
