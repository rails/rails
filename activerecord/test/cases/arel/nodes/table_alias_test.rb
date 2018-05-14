# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    describe "table alias" do
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
    end
  end
end
