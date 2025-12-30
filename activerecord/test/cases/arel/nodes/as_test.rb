# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class AsTest < Arel::Spec
      describe "#as" do
        it "makes an AS node" do
          attr = Table.new(:users)[:id]
          as = attr.as(Arel.sql("foo"))
          assert_equal attr, as.left
          assert_equal "foo", as.right
        end

        it "converts right to SqlLiteral if a string" do
          attr = Table.new(:users)[:id]
          as = attr.as("foo")
          assert_kind_of Arel::Nodes::SqlLiteral, as.right
        end

        it "converts right to SqlLiteral if a symbol" do
          attr = Table.new(:users)[:id]
          as = attr.as(:foo)
          assert_kind_of Arel::Nodes::SqlLiteral, as.right
        end
      end

      describe "equality" do
        it "is equal with equal ivars" do
          array = [As.new("foo", "bar"), As.new("foo", "bar")]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          array = [As.new("foo", "bar"), As.new("foo", "baz")]
          assert_equal 2, array.uniq.size
        end
      end

      describe "#to_cte" do
        it "returns a Cte node using the LHS's name and the RHS as the relation" do
          table = Table.new(:users)
          as_node = As.new(table, "foo")
          cte_node = as_node.to_cte

          assert_kind_of Arel::Nodes::Cte, cte_node
          assert_equal as_node.left.name, cte_node.name
          assert_equal as_node.right, cte_node.relation
        end
      end
    end
  end
end
