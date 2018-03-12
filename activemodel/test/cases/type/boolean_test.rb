# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class BooleanTest < ActiveModel::TestCase
      VALUES_FOR_CAST = [1, "1",
                         true, "t", "true", "TRUE",
                         "on", "ON",
                         " ",
                         "\u3000\r\n", "\u0000",
                         "random string"]

      def test_type_cast_boolean
        type = Type::Boolean.new
        assert_predicate type.cast(""), :nil?
        assert_predicate type.cast(nil), :nil?

        VALUES_FOR_CAST.each do |value|
          assert type.cast(value)
        end

        # explicitly check for false vs nil
        ::ActiveModel::Type::Boolean::FALSE_VALUES.each do |value|
          assert_equal false, type.cast(value)
        end
      end
    end
  end
end
