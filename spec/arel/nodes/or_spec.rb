module Arel
  module Nodes
    describe 'or' do
      describe '#or' do
        it 'makes an OR node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          check node.expr.left.should == left
          check node.expr.right.should == right

          oror = node.or(right)
          check oror.expr.left == node
          check oror.expr.right == right
        end
      end
    end
  end
end
