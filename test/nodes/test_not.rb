require 'helper'

module Arel
  module Nodes
    describe 'not' do
      describe '#not' do
        it 'makes a NOT node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          node.expr.left.must_equal left
          node.expr.right.must_equal right

          node.or(right).not
        end
      end
    end
  end
end
