module Arel
  module Nodes
    describe 'or' do
      describe '#or' do
        it 'makes an OR node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          check node.left.should == left
          check node.right.should == right

          oror = node.or(right)
          check oror.left == node
          check oror.right == right
        end
      end
    end
  end
end
