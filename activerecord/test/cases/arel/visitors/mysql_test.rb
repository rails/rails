# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class MysqlTest < Arel::Spec
      before do
        @visitor = MySQL.new Table.engine.lease_connection
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      ###
      # :'(
      # To retrieve all rows from a certain offset up to the end of the result set,
      # you can use some large number for the second parameter.
      # https://dev.mysql.com/doc/refman/en/select.html
      it "defaults limit to 18446744073709551615" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        sql = compile(stmt)
        _(sql).must_be_like "SELECT FROM DUAL LIMIT 18446744073709551615 OFFSET 1"
      end

      it "should escape LIMIT" do
        sc = Arel::Nodes::UpdateStatement.new
        sc.relation = Table.new(:users)
        sc.limit = Nodes::Limit.new(Nodes.build_quoted("omg"))
        assert_equal("UPDATE \"users\" LIMIT 'omg'", compile(sc))
      end

      it "uses DUAL for empty from" do
        stmt = Nodes::SelectStatement.new
        sql = compile(stmt)
        _(sql).must_be_like "SELECT FROM DUAL"
      end

      describe "locking" do
        it "defaults to FOR UPDATE when locking" do
          node = Nodes::Lock.new(Arel.sql("FOR UPDATE"))
          _(compile(node)).must_be_like "FOR UPDATE"
        end

        it "allows a custom string to be used as a lock" do
          node = Nodes::Lock.new(Arel.sql("LOCK IN SHARE MODE"))
          _(compile(node)).must_be_like "LOCK IN SHARE MODE"
        end
      end

      describe "concat" do
        it "concats columns" do
          @table = Table.new(:users)
          query = @table[:name].concat(@table[:name])
          _(compile(query)).must_be_like %{
            CONCAT("users"."name", "users"."name")
          }
        end

        it "concats a string" do
          @table = Table.new(:users)
          query = @table[:name].concat(Nodes.build_quoted("abc"))
          _(compile(query)).must_be_like %{
            CONCAT("users"."name", 'abc')
          }
        end
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          _(compile(test)).must_be_like %{
            "users"."name" <=> 'Aaron Patterson'
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" <=> "users"."last_name"
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" <=> NULL }
        end
      end

      describe "Nodes::IsDistinctFrom" do
        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            NOT "users"."first_name" <=> "users"."last_name"
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ NOT "users"."name" <=> NULL }
        end
      end

      describe "Nodes::Regexp" do
        before do
          @table = Table.new(:users)
          @attr = @table[:id]
        end

        it "should know how to visit" do
          node = @table[:name].matches_regexp("foo.*")
          _(node).must_be_kind_of Nodes::Regexp
          _(compile(node)).must_be_like %{
            "users"."name" REGEXP 'foo.*'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].matches_regexp("foo.*"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" REGEXP 'foo.*')
          }
        end
      end

      describe "Nodes::NotRegexp" do
        before do
          @table = Table.new(:users)
          @attr = @table[:id]
        end

        it "should know how to visit" do
          node = @table[:name].does_not_match_regexp("foo.*")
          _(node).must_be_kind_of Nodes::NotRegexp
          _(compile(node)).must_be_like %{
            "users"."name" NOT REGEXP 'foo.*'
          }
        end

        it "can handle subqueries" do
          subquery = @table.project(:id).where(@table[:name].does_not_match_regexp("foo.*"))
          node = @attr.in subquery
          _(compile(node)).must_be_like %{
            "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT REGEXP 'foo.*')
          }
        end
      end

      describe "Nodes::Ordering" do
        it "should handle nulls first" do
          test = Table.new(:users)[:first_name].asc.nulls_first
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NOT NULL, "users"."first_name" ASC
          }
        end

        it "should handle nulls last" do
          test = Table.new(:users)[:first_name].asc.nulls_last
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NULL, "users"."first_name" ASC
          }
        end

        it "should handle nulls first reversed" do
          test = Table.new(:users)[:first_name].asc.nulls_first.reverse
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NULL, "users"."first_name" DESC
          }
        end

        it "should handle nulls last reversed" do
          test = Table.new(:users)[:first_name].asc.nulls_last.reverse
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NOT NULL, "users"."first_name" DESC
          }
        end
      end

      describe "Nodes::Cte" do
        it "ignores MATERIALIZED modifiers" do
          cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star), materialized: true)

          _(compile(cte)).must_be_like %{
            "foo" AS (SELECT * FROM "bar")
          }
        end

        it "ignores NOT MATERIALIZED modifiers" do
          cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star), materialized: false)

          _(compile(cte)).must_be_like %{
            "foo" AS (SELECT * FROM "bar")
          }
        end
      end
    end
  end
end
