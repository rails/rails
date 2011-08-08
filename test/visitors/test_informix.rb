require 'helper'

module Arel
  module Visitors
    describe 'the informix visitor' do
      before do
        @visitor = Informix.new Table.engine.connection_pool
      end

      it 'uses LIMIT n to limit results' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT LIMIT 1"
      end

      it 'uses LIMIT n in updates with a limit' do
        stmt = Nodes::UpdateStatement.new
        stmt.limit = Nodes::Limit.new(1)
        stmt.key = 'id'
        sql = @visitor.accept(stmt)
        sql.must_be_like "UPDATE NULL WHERE 'id' IN (SELECT LIMIT 1 'id')"
      end

      it 'uses SKIP n to jump results' do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(10)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT SKIP 10"
      end

      it 'uses SKIP before LIMIT' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        stmt.offset = Nodes::Offset.new(1)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT SKIP 1 LIMIT 1"
      end

    end
  end
end
