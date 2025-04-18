# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class TableAliasTest < Arel::Spec
      describe "equality" do
        it "is equal with equal ivars" do
          relation1 = Table.new(:users)
          node1     = TableAlias.new relation1, :foo
          relation2 = Table.new(:users)
          node2     = TableAlias.new relation2, :foo
          array = [node1, node2]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          relation1 = Table.new(:users)
          node1     = TableAlias.new relation1, :foo
          relation2 = Table.new(:users)
          node2     = TableAlias.new relation2, :bar
          array = [node1, node2]
          assert_equal 2, array.uniq.size
        end
      end

      describe "#to_cte" do
        it "returns a Cte node using the TableAlias's name and relation" do
          relation = Table.new(:users).project(Arel.star)
          table_alias = TableAlias.new(relation, :foo)
          cte = table_alias.to_cte

          assert_kind_of Arel::Nodes::Cte, cte
          assert_equal :foo, cte.name
          assert_equal relation, cte.relation
        end
      end
    end
  end
end
