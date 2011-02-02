require 'helper'

module Arel
  module Visitors
    describe 'the mssql visitor' do
      before do
        @visitor = MSSQL.new Table.engine
      end

      it 'uses TOP to limit results' do
        stmt = Nodes::SelectStatement.new
        stmt.cores.last.top = Nodes::Top.new(1)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT TOP 1"
      end

      it 'uses TOP in updates with a limit' do
        stmt = Nodes::UpdateStatement.new
        stmt.limit = Nodes::Limit.new(1)
        stmt.key = 'id'
        sql = @visitor.accept(stmt)
        sql.must_be_like "UPDATE NULL WHERE 'id' IN (SELECT TOP 1 'id' )"
      end

    end
  end
end
