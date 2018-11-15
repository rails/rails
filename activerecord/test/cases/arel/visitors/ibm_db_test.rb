# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class IbmDbTest < Arel::Spec
      before do
        @visitor = IBM_DB.new Table.engine.connection
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it "uses FETCH FIRST n ROWS to limit results" do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        sql = compile(stmt)
        sql.must_be_like "SELECT FETCH FIRST 1 ROWS ONLY"
      end

      it "uses FETCH FIRST n ROWS in updates with a limit" do
        table = Table.new(:users)
        stmt = Nodes::UpdateStatement.new
        stmt.relation = table
        stmt.limit = Nodes::Limit.new(Nodes.build_quoted(1))
        stmt.key = table[:id]
        sql = compile(stmt)
        sql.must_be_like "UPDATE \"users\" WHERE \"users\".\"id\" IN (SELECT \"users\".\"id\" FROM \"users\" FETCH FIRST 1 ROWS ONLY)"
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          compile(test).must_be_like %{
            DECODE("users"."name", 'Aaron Patterson', 0, 1) = 0
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          compile(test).must_be_like %{
            DECODE("users"."first_name", "users"."last_name", 0, 1) = 0
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
            DECODE("users"."first_name", "users"."last_name", 0, 1) = 1
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
