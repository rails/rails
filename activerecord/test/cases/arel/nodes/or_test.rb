# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class OrTest < Arel::Test
      test "#or makes an OR node" do
        attr = Table.new(:users)[:id]
        left  = attr.eq(10)
        right = attr.eq(11)
        node  = left.or right

        assert_equal left, node.expr.left
        assert_equal right, node.expr.right

        oror = node.or(right)
        assert_equal node, oror.expr.left
        assert_equal right, oror.expr.right
      end

      test "equality is equal with equal ivars" do
        array = [Or.new(["foo", "bar"]), Or.new(["foo", "bar"])]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different ivars" do
        array = [Or.new(["foo", "bar"]), Or.new(["foo", "baz"])]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
