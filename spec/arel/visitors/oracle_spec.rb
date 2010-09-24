require 'spec_helper'

module Arel
  module Visitors
    describe 'the oracle visitor' do
      before do
        @visitor = Oracle.new Table.engine
      end

      it 'modifies order when there is distinct and first value' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('foo')
        sql = @visitor.accept(stmt)
        sql.should be_like %{
          SELECT #{select} ORDER BY alias_0__
        }
      end

      it 'is idempotent with crazy query' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('foo')

        sql = @visitor.accept(stmt)
        sql2 = @visitor.accept(stmt)
        check sql.should == sql2
      end

      describe 'Nodes::SelectStatement' do
        describe 'limit' do
          it 'adds a rownum clause' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = 10
            sql = @visitor.accept stmt
            sql.should be_like %{ SELECT WHERE ROWNUM <= 10 }
          end

          it 'is idempotent' do
            stmt = Nodes::SelectStatement.new
            stmt.orders << Nodes::SqlLiteral.new('foo')
            stmt.limit = 10
            sql = @visitor.accept stmt
            sql2 = @visitor.accept stmt
            check sql.should == sql2
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

          it 'is idempotent with different subquery' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = 10
            stmt.offset = Nodes::Offset.new(10)
            sql = @visitor.accept stmt
            sql2 = @visitor.accept stmt
            check sql.should == sql2
          end
        end
      end
    end
  end
end
