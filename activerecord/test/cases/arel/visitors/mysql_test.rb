# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class MysqlTest < Arel::Test
      setup do
        @visitor = MySQL.new Table.engine.lease_connection
      end

      ###
      # :'(
      # To retrieve all rows from a certain offset up to the end of the result set,
      # you can use some large number for the second parameter.
      # https://dev.mysql.com/doc/refman/en/select.html
      test "defaults limit to 18446744073709551615" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        sql = compile(stmt)
        assert_like "SELECT FROM DUAL LIMIT 18446744073709551615 OFFSET 1", sql
      end

      test "should escape LIMIT" do
        sc = Arel::Nodes::UpdateStatement.new
        sc.relation = Table.new(:users)
        sc.limit = Nodes::Limit.new(Nodes.build_quoted("omg"))
        assert_equal "UPDATE \"users\" LIMIT 'omg'", compile(sc)
      end

      test "uses DUAL for empty from" do
        stmt = Nodes::SelectStatement.new
        sql = compile(stmt)
        assert_like "SELECT FROM DUAL", sql
      end

      test "locking defaults to FOR UPDATE when locking" do
        node = Nodes::Lock.new(Arel.sql("FOR UPDATE"))
        assert_like "FOR UPDATE", compile(node)
      end

      test "locking allows a custom string to be used as a lock" do
        node = Nodes::Lock.new(Arel.sql("LOCK IN SHARE MODE"))
        assert_like "LOCK IN SHARE MODE", compile(node)
      end

      test "concat concats columns" do
        table = Table.new(:users)
        query = table[:name].concat(table[:name])
        assert_like %{
          CONCAT("users"."name", "users"."name")
        }, compile(query)
      end

      test "concat concats a string" do
        table = Table.new(:users)
        query = table[:name].concat(Nodes.build_quoted("abc"))
        assert_like %{
          CONCAT("users"."name", 'abc')
        }, compile(query)
      end

      test "Nodes::IsNotDistinctFrom should construct a valid generic SQL statement" do
        node = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
        assert_like %{
          "users"."name" <=> 'Aaron Patterson'
        }, compile(node)
      end

      test "Nodes::IsNotDistinctFrom should handle column names on both sides" do
        node = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          "users"."first_name" <=> "users"."last_name"
        }, compile(node)
      end

      test "Nodes::IsNotDistinctFrom should handle nil" do
        table = Table.new(:users)
        value = Nodes.build_quoted(nil, table[:active])
        sql = compile Nodes::IsNotDistinctFrom.new(table[:name], value)
        assert_like %{ "users"."name" <=> NULL }, sql
      end

      test "Nodes::IsDistinctFrom should handle column names on both sides" do
        node = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          NOT "users"."first_name" <=> "users"."last_name"
        }, compile(node)
      end

      test "Nodes::IsDistinctFrom should handle nil" do
        table = Table.new(:users)
        value = Nodes.build_quoted(nil, table[:active])
        sql = compile Nodes::IsDistinctFrom.new(table[:name], value)
        assert_like %{ NOT "users"."name" <=> NULL }, sql
      end

      test "Nodes::Regexp should know how to visit" do
        table = Table.new(:users)
        node = table[:name].matches_regexp("foo.*")
        assert_kind_of Nodes::Regexp, node
        assert_like %{
          "users"."name" REGEXP 'foo.*'
        }, compile(node)
      end

      test "Nodes::Regexp can handle subqueries" do
        table = Table.new(:users)
        attr = table[:id]
        subquery = table.project(:id).where(table[:name].matches_regexp("foo.*"))
        node = attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" REGEXP 'foo.*')
        }, compile(node)
      end

      test "Nodes::NotRegexp should know how to visit" do
        table = Table.new(:users)
        node = table[:name].does_not_match_regexp("foo.*")
        assert_kind_of Nodes::NotRegexp, node
        assert_like %{
          "users"."name" NOT REGEXP 'foo.*'
        }, compile(node)
      end

      test "Nodes::NotRegexp can handle subqueries" do
        table = Table.new(:users)
        attr = table[:id]
        subquery = table.project(:id).where(table[:name].does_not_match_regexp("foo.*"))
        node = attr.in subquery
        assert_like %{
          "users"."id" IN (SELECT id FROM "users" WHERE "users"."name" NOT REGEXP 'foo.*')
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls first" do
        node = Table.new(:users)[:first_name].asc.nulls_first
        assert_like %{
          "users"."first_name" IS NOT NULL, "users"."first_name" ASC
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls last" do
        node = Table.new(:users)[:first_name].asc.nulls_last
        assert_like %{
          "users"."first_name" IS NULL, "users"."first_name" ASC
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls first reversed" do
        node = Table.new(:users)[:first_name].asc.nulls_first.reverse
        assert_like %{
          "users"."first_name" IS NULL, "users"."first_name" DESC
        }, compile(node)
      end

      test "Nodes::Ordering should handle nulls last reversed" do
        node = Table.new(:users)[:first_name].asc.nulls_last.reverse
        assert_like %{
          "users"."first_name" IS NOT NULL, "users"."first_name" DESC
        }, compile(node)
      end

      test "Nodes::Cte ignores MATERIALIZED modifiers" do
        cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star), materialized: true)

        assert_like %{
          "foo" AS (SELECT * FROM "bar")
        }, compile(cte)
      end

      test "Nodes::Cte ignores NOT MATERIALIZED modifiers" do
        cte = Nodes::Cte.new("foo", Table.new(:bar).project(Arel.star), materialized: false)

        assert_like %{
          "foo" AS (SELECT * FROM "bar")
        }, compile(cte)
      end

      private
        def compile(node)
          @visitor.accept(node, Collectors::SQLString.new).value
        end
    end
  end
end
