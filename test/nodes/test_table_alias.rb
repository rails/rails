require 'helper'
require 'ostruct'

module Arel
  module Nodes
    describe 'table alias' do
      it 'has an #engine which delegates to the relation' do
        engine   = 'vroom'
        relation = Table.new(:users, engine)

        node = TableAlias.new relation, :foo
        node.engine.must_equal engine
      end

      describe 'equality' do
        it 'is equal with equal ivars' do
          relation1 = Table.new(:users, 'vroom')
          node1     = TableAlias.new relation1, :foo
          relation2 = Table.new(:users, 'vroom')
          node2     = TableAlias.new relation2, :foo
          array = [node1, node2]
          assert_equal 1, array.uniq.size
        end

        it 'is not equal with different ivars' do
          relation1 = Table.new(:users, 'vroom')
          node1     = TableAlias.new relation1, :foo
          relation2 = Table.new(:users, 'vroom')
          node2     = TableAlias.new relation2, :bar
          array = [node1, node2]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
