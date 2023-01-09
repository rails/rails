# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/object/json"

module ActiveModel
  module Type
    class ValueTest < ActiveModel::TestCase
      def test_type_equality
        assert_equal Type::Value.new, Type::Value.new
        assert_not_equal Type::Value.new, Type::Integer.new
        assert_not_equal Type::Value.new(precision: 1), Type::Value.new(precision: 2)
      end

      def test_as_json_not_defined
        assert_raises NoMethodError do
          Type::Value.new.as_json
        end
      end
    end
  end
end
