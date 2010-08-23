module Arel
  module Nodes
    describe 'equality' do
      describe 'or' do
        it 'makes an OR node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.or right
          check node.left.should == left
          check node.right.should == right
        end
      end

      describe 'and' do
        it 'makes and AND node' do
          attr = Table.new(:users)[:id]
          left  = attr.eq(10)
          right = attr.eq(11)
          node  = left.and right
          check node.left.should == left
          check node.right.should == right
        end
      end
    end
  end
end
