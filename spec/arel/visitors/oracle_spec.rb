require 'spec_helper'

module Arel
  module Visitors
    describe 'the oracle visitor' do
      before do
        @visitor = Oracle.new Table.engine
      end

      describe 'Nodes::SelectStatement' do
        describe 'limit' do
          it 'adds a rownum clause' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = 10
            sql = @visitor.accept stmt
            sql.should be_like %{ SELECT WHERE ROWNUM <= 10 }
          end

          it 'creates a subquery when there is order_by' do
            stmt = Nodes::SelectStatement.new
            stmt.orders << Nodes::SqlLiteral.new('foo')
            stmt.limit = 10
            sql = @visitor.accept stmt
            sql.should be_like %{
              SELECT * FROM (SELECT ORDER BY foo) WHERE ROWNUM <= 10
            }
          end

          it 'creates a different subquery when there is an offset' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = 10
            stmt.offset = Nodes::Offset.new(10)
            sql = @visitor.accept stmt
            sql.should be_like %{
              SELECT * FROM (
                SELECT raw_sql_.*, rownum raw_rnum_
                FROM (SELECT ) raw_sql_
                WHERE rownum <= 20
              )
              WHERE raw_rnum_ > 10
            }
          end
        end
      end
    end
  end
end
