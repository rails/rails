# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class SqliteTest < Arel::Test
      setup do
        @visitor = SQLite.new Table.engine.lease_connection
      end

      test "defaults limit to -1" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        sql = @visitor.accept(stmt, Collectors::SQLString.new).value
        assert_like "SELECT LIMIT -1 OFFSET 1", sql
      end

      test "does not support locking" do
        node = Nodes::Lock.new(Arel.sql("FOR UPDATE"))
        assert_equal "", @visitor.accept(node, Collectors::SQLString.new).value
      end

      test "Nodes::IsNotDistinctFrom should construct a valid generic SQL statement" do
        test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
        assert_like %{
          "users"."name" IS 'Aaron Patterson'
        }, compile(test)
      end

      test "Nodes::IsNotDistinctFrom should handle column names on both sides" do
        test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          "users"."first_name" IS "users"."last_name"
        }, compile(test)
      end

      test "Nodes::IsNotDistinctFrom should handle nil" do
        @table = Table.new(:users)
        val = Nodes.build_quoted(nil, @table[:active])
        sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
        assert_like %{ "users"."name" IS NULL }, sql
      end

      test "Nodes::IsDistinctFrom should handle column names on both sides" do
        test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
        assert_like %{
          "users"."first_name" IS NOT "users"."last_name"
        }, compile(test)
      end

      test "Nodes::IsDistinctFrom should handle nil" do
        @table = Table.new(:users)
        val = Nodes.build_quoted(nil, @table[:active])
        sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
        assert_like %{ "users"."name" IS NOT NULL }, sql
      end

      private
        def compile(node)
          @visitor.accept(node, Collectors::SQLString.new).value
        end
    end
  end
end
