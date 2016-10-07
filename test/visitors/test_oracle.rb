require 'helper'

module Arel
  module Visitors
    describe 'the oracle visitor' do
      before do
        @visitor = Oracle.new Table.engine.connection
        @table = Table.new(:users)
      end

      def compile node
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it 'modifies order when there is distinct and first value' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('foo')
        sql = compile(stmt)
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

        sql = compile(stmt)
        sql2 = compile(stmt)
        sql.must_equal sql2
      end

      it 'splits orders with commas' do
        # *sigh*
        select = "DISTINCT foo.id, FIRST_VALUE(projects.name) OVER (foo) AS alias_0__"
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.projections << Nodes::SqlLiteral.new(select)
        stmt.orders << Nodes::SqlLiteral.new('foo, bar')
        sql = compile(stmt)
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
        sql = compile(stmt)
        sql.must_be_like %{
          SELECT #{select} ORDER BY alias_0__ DESC, alias_1__
        }
      end

      describe 'Nodes::SelectStatement' do
        describe 'limit' do
          it 'adds a rownum clause' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(10)
            sql = compile stmt
            sql.must_be_like %{ SELECT WHERE ROWNUM <= 10 }
          end

          it 'is idempotent' do
            stmt = Nodes::SelectStatement.new
            stmt.orders << Nodes::SqlLiteral.new('foo')
            stmt.limit = Nodes::Limit.new(10)
            sql = compile stmt
            sql2 = compile stmt
            sql.must_equal sql2
          end

          it 'creates a subquery when there is order_by' do
            stmt = Nodes::SelectStatement.new
            stmt.orders << Nodes::SqlLiteral.new('foo')
            stmt.limit = Nodes::Limit.new(10)
            sql = compile stmt
            sql.must_be_like %{
              SELECT * FROM (SELECT ORDER BY foo ) WHERE ROWNUM <= 10
            }
          end

          it 'creates a subquery when there is group by' do
            stmt = Nodes::SelectStatement.new
            stmt.cores.first.groups << Nodes::SqlLiteral.new('foo')
            stmt.limit = Nodes::Limit.new(10)
            sql = compile stmt
            sql.must_be_like %{
              SELECT * FROM (SELECT GROUP BY foo ) WHERE ROWNUM <= 10
            }
          end

          it 'creates a subquery when there is DISTINCT' do
            stmt = Nodes::SelectStatement.new
            stmt.cores.first.set_quantifier = Arel::Nodes::Distinct.new
            stmt.cores.first.projections << Nodes::SqlLiteral.new('id')
            stmt.limit = Arel::Nodes::Limit.new(10)
            sql = compile stmt
            sql.must_be_like %{
              SELECT * FROM (SELECT DISTINCT id ) WHERE ROWNUM <= 10
            }
          end

          it 'creates a different subquery when there is an offset' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(10)
            stmt.offset = Nodes::Offset.new(10)
            sql = compile stmt
            sql.must_be_like %{
              SELECT * FROM (
                SELECT raw_sql_.*, rownum raw_rnum_
                FROM (SELECT ) raw_sql_
                 WHERE rownum <= 20
              )
              WHERE raw_rnum_ > 10
            }
          end

          it 'creates a subquery when there is limit and offset with BindParams' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(Nodes::BindParam.new)
            stmt.offset = Nodes::Offset.new(Nodes::BindParam.new)
            sql = compile stmt
            sql.must_be_like %{
              SELECT * FROM (
                SELECT raw_sql_.*, rownum raw_rnum_
                FROM (SELECT ) raw_sql_
                 WHERE rownum <= (:a1 + :a2)
              )
              WHERE raw_rnum_ > :a1
            }
          end

          it 'is idempotent with different subquery' do
            stmt = Nodes::SelectStatement.new
            stmt.limit = Nodes::Limit.new(10)
            stmt.offset = Nodes::Offset.new(10)
            sql = compile stmt
            sql2 = compile stmt
            sql.must_equal sql2
          end
        end

        describe 'only offset' do
          it 'creates a select from subquery with rownum condition' do
            stmt = Nodes::SelectStatement.new
            stmt.offset = Nodes::Offset.new(10)
            sql = compile stmt
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
        sql = compile Nodes::Except.new(left, right)
        sql.must_be_like %{
          ( SELECT * FROM users WHERE age > 10 MINUS SELECT * FROM users WHERE age > 20 )
        }
      end

      describe 'locking' do
        it 'defaults to FOR UPDATE when locking' do
          node = Nodes::Lock.new(Arel.sql('FOR UPDATE'))
          compile(node).must_be_like "FOR UPDATE"
        end
      end

      describe "Nodes::BindParam" do
        it "increments each bind param" do
          query = @table[:name].eq(Arel::Nodes::BindParam.new)
            .and(@table[:id].eq(Arel::Nodes::BindParam.new))
          compile(query).must_be_like %{
            "users"."name" = :a1 AND "users"."id" = :a2
          }
        end
      end
    end
  end
end
