# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class InformixTest < Arel::Spec
      before do
        @visitor = Informix.new Table.engine.connection
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it "uses FIRST n to limit results" do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        sql = compile(stmt)
        sql.must_be_like "SELECT FIRST 1"
      end

      it "uses FIRST n in updates with a limit" do
        table = Table.new(:users)
        stmt = Nodes::UpdateStatement.new
        stmt.relation = table
        stmt.limit = Nodes::Limit.new(Nodes.build_quoted(1))
        stmt.key = table[:id]
        sql = compile(stmt)
        sql.must_be_like "UPDATE \"users\" WHERE \"users\".\"id\" IN (SELECT FIRST 1 \"users\".\"id\" FROM \"users\")"
      end

      it "uses SKIP n to jump results" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(10)
        sql = compile(stmt)
        sql.must_be_like "SELECT SKIP 10"
      end

      it "uses SKIP before FIRST" do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        stmt.offset = Nodes::Offset.new(1)
        sql = compile(stmt)
        sql.must_be_like "SELECT SKIP 1 FIRST 1"
      end

      it "uses INNER JOIN to perform joins" do
        core = Nodes::SelectCore.new
        table = Table.new(:posts)
        core.source = Nodes::JoinSource.new(table, [table.create_join(Table.new(:comments))])

        stmt = Nodes::SelectStatement.new([core])
        sql = compile(stmt)
        sql.must_be_like 'SELECT FROM "posts" INNER JOIN "comments"'
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          compile(test).must_be_like %{
            CASE WHEN "users"."name" = 'Aaron Patterson' OR ("users"."name" IS NULL AND 'Aaron Patterson' IS NULL) THEN 0 ELSE 1 END = 0
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          compile(test).must_be_like %{
            CASE WHEN "users"."first_name" = "users"."last_name" OR ("users"."first_name" IS NULL AND "users"."last_name" IS NULL) THEN 0 ELSE 1 END = 0
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
          sql.must_be_like %{ "users"."name" IS NULL }
        end
      end

      describe "Nodes::IsDistinctFrom" do
        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
          compile(test).must_be_like %{
            CASE WHEN "users"."first_name" = "users"."last_name" OR ("users"."first_name" IS NULL AND "users"."last_name" IS NULL) THEN 0 ELSE 1 END = 1
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
          sql.must_be_like %{ "users"."name" IS NOT NULL }
        end
      end
    end
  end
end
