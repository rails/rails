require 'helper'
require 'ostruct'

module Arel
  module Nodes
    describe 'table alias' do
      it 'has an #engine which delegates to the relation' do
        engine   = Object.new
        relation = OpenStruct.new(:engine => engine)

        node = TableAlias.new relation, :foo
        node.engine.must_equal engine
      end
    end
  end
end
