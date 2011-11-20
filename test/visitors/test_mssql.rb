require 'helper'

module Arel
  module Visitors
    describe 'the mssql visitor' do
      before do
        @visitor = MSSQL.new Table.engine.connection
        @table = Arel::Table.new "users"
      end

      it 'should not modify query if no offset or limit' do
        stmt = Nodes::SelectStatement.new
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT"
      end

      it 'should go over table PK if no .order() or .group()' do
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.from = @table
        stmt.limit = Nodes::Limit.new(10)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY \"users\".\"id\") as _row_num FROM \"users\" ) as _t WHERE _row_num BETWEEN 1 AND 10"
      end

      it 'should go over query ORDER BY if .order()' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(10)
        stmt.orders << Nodes::SqlLiteral.new('order_by')
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY order_by) as _row_num) as _t WHERE _row_num BETWEEN 1 AND 10"
      end

      it 'should go over query GROUP BY if no .order() and there is .group()' do
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.groups << Nodes::SqlLiteral.new('group_by')
        stmt.limit = Nodes::Limit.new(10)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY group_by) as _row_num GROUP BY group_by) as _t WHERE _row_num BETWEEN 1 AND 10"
      end

      it 'should use BETWEEN if both .limit() and .offset' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(10)
        stmt.offset = Nodes::Offset.new(20)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY ) as _row_num) as _t WHERE _row_num BETWEEN 21 AND 30"
      end

      it 'should use >= if only .offset' do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(20)
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY ) as _row_num) as _t WHERE _row_num >= 21"
      end

      it 'should generate subquery for .count' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(10)
        stmt.cores.first.projections << Nodes::Count.new('*')
        sql = @visitor.accept(stmt)
        sql.must_be_like "SELECT COUNT(1) as count_id FROM (SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY ) as _row_num) as _t WHERE _row_num BETWEEN 1 AND 10) AS subquery"
      end

    end
  end
end
