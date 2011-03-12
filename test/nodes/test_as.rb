require 'helper'

module Arel
  module Nodes
    describe 'As' do
      describe '#as' do
        it 'makes an AS node' do
          attr = Table.new(:users)[:id]
          as = attr.as(Arel.sql('foo'))
          assert_equal attr, as.left
          assert_equal 'foo', as.right
        end

        it 'converts right to SqlLiteral if a string' do
          attr = Table.new(:users)[:id]
          as = attr.as('foo')
          assert_kind_of Arel::Nodes::SqlLiteral, as.right
        end
      end
    end
  end
end
