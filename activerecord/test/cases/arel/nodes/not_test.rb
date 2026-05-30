# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class NotTest < Arel::Test
      test "#not makes a NOT node" do
        attr = Table.new(:users)[:id]
        expr  = attr.eq(10)
        node  = expr.not

        assert_kind_of Not, node
        assert_equal expr, node.expr
      end

      test "equality is equal with equal ivars" do
        array = [Not.new("foo"), Not.new("foo")]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different ivars" do
        array = [Not.new("foo"), Not.new("baz")]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
