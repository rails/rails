# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class BindParamTest < Arel::Test
      test "is equal to other bind params with the same value" do
        assert_equal BindParam.new(1), BindParam.new(1)
        assert_equal BindParam.new("foo"), BindParam.new("foo")
      end

      test "is not equal to other nodes" do
        assert_not_equal Node.new, BindParam.new(nil)
      end

      test "is not equal to bind params with different values" do
        assert_not_equal BindParam.new(2), BindParam.new(1)
      end
    end
  end
end
