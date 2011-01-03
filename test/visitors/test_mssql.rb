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
    end
  end
end
