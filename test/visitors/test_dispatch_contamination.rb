require 'helper'

module Arel
  module Visitors
    describe 'avoiding contamination between visitor dispatch tables' do
      before do
        @connection = Table.engine.connection
        @table = Table.new(:users)
      end

      it 'dispatches properly after failing upwards' do
        node = Nodes::Union.new(Nodes::True.new, Nodes::False.new)
        assert_equal "( TRUE UNION FALSE )", node.to_sql

        node.first # from Nodes::Node's Enumerable mixin

        assert_equal "( TRUE UNION FALSE )", node.to_sql
      end
    end
  end
end

