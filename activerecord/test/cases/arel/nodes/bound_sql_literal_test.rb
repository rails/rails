# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class BoundSqlLiteralTest < Arel::Test
      test "equality is equal with equal components" do
        node1 = BoundSqlLiteral.new("foo + ?", [2], {})
        node2 = BoundSqlLiteral.new("foo + ?", [2], {})

        array = [node1, node2]

        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different components" do
        node1 = BoundSqlLiteral.new("foo + ?", [2], {})
        node2 = BoundSqlLiteral.new("foo + ?", [3], {})
        node3 = BoundSqlLiteral.new("foo + :bar", [], { bar: 2 })

        array = [node1, node2, node3]

        assert_equal 3, array.uniq.size
      end
    end
  end
end
