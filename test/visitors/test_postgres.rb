require 'helper'

module Arel
  module Visitors
    describe 'the postgres visitor' do
      before do
        @visitor = PostgreSQL.new Table.engine.connection
        @table = Table.new(:users)
        @attr = @table[:id]
      end

      def compile node
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      describe 'locking' do
        it 'defaults to FOR UPDATE' do
          compile(Nodes::Lock.new(Arel.sql('FOR UPDATE'))).must_be_like %{
            FOR UPDATE
          }
        end

        it 'allows a custom string to be used as a lock' do
          node = Nodes::Lock.new(Arel.sql('FOR SHARE'))
          compile(node).must_be_like %{
            FOR SHARE
          }
        end
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::SelectStatement.new
        sc.limit = Nodes::Limit.new(Nodes.build_quoted("omg"))
        sc.cores.first.projections << Arel.sql('DISTINCT ON')
        sc.orders << Arel.sql("xyz")
        sql =  compile(sc)
        assert_match(/LIMIT 'omg'/, sql)
        assert_equal 1, sql.scan(/LIMIT/).length, 'should have one limit'
      end

      it 'should support DISTINCT ON' do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::DistinctOn.new(Arel.sql('aaron'))
        assert_match 'DISTINCT ON ( aaron )', compile(core)
      end

      it 'should support DISTINCT' do
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::Distinct.new
        assert_equal 'SELECT DISTINCT', compile(core)
      end

      describe "Nodes::Matches" do
        it "should know how to visit" do
          node = @table[:name].matches('foo%')
          compile(node).must_be_like %{
            "users"."name" ILIKE 'foo%'
          }
        end

        it 'can handle subqueries' do
          subquery = @table.project(:id).where(@table[:name].matches('foo%'))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" ILIKE 'foo%')
          }
        end
      end

      describe "Nodes::DoesNotMatch" do
        it "should know how to visit" do
          node = @table[:name].does_not_match('foo%')
          compile(node).must_be_like %{
            "users"."name" NOT ILIKE 'foo%'
          }
        end

        it 'can handle subqueries' do
          subquery = @table.project(:id).where(@table[:name].does_not_match('foo%'))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT ILIKE 'foo%')
          }
        end
      end

      describe "Nodes::Regexp" do
        it "should know how to visit" do
          node = Arel::Nodes::Regexp.new(@table[:name], Nodes.build_quoted('foo%'))
          compile(node).must_be_like %{
            "users"."name" ~ 'foo%'
          }
        end

        it 'can handle subqueries' do
          subquery = @table.project(:id).where(Arel::Nodes::Regexp.new(@table[:name], Nodes.build_quoted('foo%')))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" ~ 'foo%')
          }
        end
      end

      describe "Nodes::NotRegexp" do
        it "should know how to visit" do
          node = Arel::Nodes::NotRegexp.new(@table[:name], Nodes.build_quoted('foo%'))
          compile(node).must_be_like %{
            "users"."name" !~ 'foo%'
          }
        end

        it 'can handle subqueries' do
          subquery = @table.project(:id).where(Arel::Nodes::NotRegexp.new(@table[:name], Nodes.build_quoted('foo%')))
          node = @attr.in subquery
          compile(node).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" !~ 'foo%')
          }
        end
      end
    end
  end
end
