require 'helper'

module Arel
  module Nodes
    describe 'not' do
      describe '#not' do
        it 'makes a NOT node' do
          attr = Table.new(:users)[:id]
          expr  = attr.eq(10)
          node  = expr.not
          node.must_be_kind_of Not
          node.expr.must_equal expr
        end
      end
    end
  end
end
