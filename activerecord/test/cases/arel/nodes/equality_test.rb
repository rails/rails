# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class EqualityTest < Arel::Test
      # FIXME: backwards compat
      test "backwards compat to_sql takes an engine" do
        engine = FakeRecord::Base.new
        engine.lease_connection.extend Module.new {
          attr_accessor :quote_count
          def quote(*args) @quote_count += 1; super; end
          def quote_column_name(*args) @quote_count += 1; super; end
          def quote_table_name(*args) @quote_count += 1; super; end
        }
        engine.lease_connection.quote_count = 0

        attr = Table.new(:users)[:id]
        test = attr.eq(10)
        test.to_sql engine
        assert_equal 3, engine.lease_connection.quote_count
      end

      test "or makes an OR node" do
        attr = Table.new(:users)[:id]
        left  = attr.eq(10)
        right = attr.eq(11)
        node  = left.or right
        assert_equal left, node.expr.left
        assert_equal right, node.expr.right
      end

      test "and makes and AND node" do
        attr = Table.new(:users)[:id]
        left  = attr.eq(10)
        right = attr.eq(11)
        node  = left.and right
        assert_equal left, node.left
        assert_equal right, node.right
      end

      test "is equal with equal ivars" do
        array = [Equality.new("foo", "bar"), Equality.new("foo", "bar")]
        assert_equal 1, array.uniq.size
      end

      test "is not equal with different ivars" do
        array = [Equality.new("foo", "bar"), Equality.new("foo", "baz")]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
