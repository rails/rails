require 'helper'

module Arel
  module Visitors
    describe 'the oracle visitor' do
      before do
        @visitor = Oracle.new Table.engine.connection_pool
      end

      it 'modifies order when there is distinct and first value' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('foo')
        sql = @visitor.accept(stmt)
        sql.must_be_like %{
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
        sql.must_equal sql2
      end

      it 'splits orders with commas' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('foo, bar')
        sql = @visitor.accept(stmt)
        sql.must_be_like %{
          SELECT #{select} ORDER BY alias_0__, alias_1__
        }
      end

      it 'splits orders with commas and function calls' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('NVL(LOWER(bar, foo), foo) DESC, UPPER(baz)')
        sql = @visitor.accept(stmt)
        sql.must_be_like %{
          SELECT #{select} ORDER BY alias_0__ DESC, alias_1__
        }
      end

      describe 'Nodes::SelectStatement' do
        describe 'limit' do
          it 'adds a rownum clause' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(10)
            sql = @visitor.accept stmt
            sql.must_be_like %{ SELECT WHERE ROWNUM <= 10 }
          end

          it 'is idempotent' do
            stmt = Nodes::SelectStatement.new
            stmt.orders << Nodes::SqlLiteral.new('foo')
            stmt.limit = Nodes::Limit.new(10)
            sql = @visitor.accept stmt
            sql2 = @visitor.accept stmt
            sql.must_equal sql2
          end

          it 'creates a subquery when there is order_by' do
            stmt = Nodes::SelectStatement.new
            stmt.orders << Nodes::SqlLiteral.new('foo')
            stmt.limit = Nodes::Limit.new(10)
            sql = @visitor.accept stmt
            sql.must_be_like %{
              SELECT * FROM (SELECT ORDER BY foo) WHERE ROWNUM <= 10
            }
          end

          it 'creates a subquery when there is DISTINCT' do
            stmt = Nodes::SelectStatement.new
            stmt.cores.first.projections << Nodes::SqlLiteral.new('DISTINCT id')
            stmt.limit = Arel::Nodes::Limit.new(10)
            sql = @visitor.accept stmt
            sql.must_be_like %{
              SELECT * FROM (SELECT DISTINCT id) WHERE ROWNUM <= 10
            }
          end

          it 'creates a different subquery when there is an offset' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(10)
            stmt.offset = Nodes::Offset.new(10)
            sql = @visitor.accept stmt
            sql.must_be_like %{
              SELECT * FROM (
                SELECT raw_sql_.*, rownum raw_rnum_
                FROM (SELECT) raw_sql_
                WHERE rownum <= 20
              )
              WHERE raw_rnum_ > 10
            }
          end

          it 'is idempotent with different subquery' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(10)
            stmt.offset = Nodes::Offset.new(10)
            sql = @visitor.accept stmt
            sql2 = @visitor.accept stmt
            sql.must_equal sql2
          end
        end

        describe 'only offset' do
          it 'creates a select from subquery with rownum condition' do
            stmt = Nodes::SelectStatement.new
            stmt.offset = Nodes::Offset.new(10)
            sql = @visitor.accept stmt
            sql.must_be_like %{
              SELECT * FROM (
                SELECT raw_sql_.*, rownum raw_rnum_
                FROM (SELECT) raw_sql_
              )
              WHERE raw_rnum_ > 10
            }
          end
        end

      end

      it 'modified except to be minus' do
        left = Nodes::SqlLiteral.new("SELECT * FROM users WHERE age > 10")
        right = Nodes::SqlLiteral.new("SELECT * FROM users WHERE age > 20")
        sql = @visitor.accept Nodes::Except.new(left, right)
        sql.must_be_like %{
          ( SELECT * FROM users WHERE age > 10 MINUS SELECT * FROM users WHERE age > 20 )
        }
      end
    end
  end
end
