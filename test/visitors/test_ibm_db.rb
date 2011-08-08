require 'helper'

module Arel
  module Visitors
    describe 'the ibm_db visitor' do
      before do
        @visitor = IBM_DB.new Table.engine.connection_pool
      end

      it 'uses FETCH FIRST n ROWS to limit results' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT FETCH FIRST 1 ROWS ONLY"
      end

      it 'uses FETCH FIRST n ROWS in updates with a limit' do
        stmt = Nodes::UpdateStatement.new
        stmt.limit = Nodes::Limit.new(1)
        stmt.key = 'id'
        sql = @visitor.accept(stmt)
        sql.must_be_like "UPDATE NULL WHERE 'id' IN (SELECT 'id' FETCH FIRST 1 ROWS ONLY)"
      end

    end
  end
end
