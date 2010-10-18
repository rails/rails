require 'spec_helper'

module Arel
  module Nodes
    describe 'or' do
      describe '#or' do
        it 'makes an OR node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          check node.expr.left.must_equal left
          check node.expr.right.must_equal right

          oror = node.or(right)
          check oror.expr.left.must_equal node
          check oror.expr.right.must_equal right
        end
      end
    end
  end
end
