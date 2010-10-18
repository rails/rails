require 'helper'

module Arel
  module Nodes
    describe 'or' do
      describe '#or' do
        it 'makes an OR node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          node.expr.left.must_equal left
          node.expr.right.must_equal right

          oror = node.or(right)
          oror.expr.left.must_equal node
          oror.expr.right.must_equal right
        end
      end
    end
  end
end
