# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class MssqlTest < Arel::Spec
      before do
        @visitor = MSSQL.new Table.engine.connection
        @table = Arel::Table.new "users"
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it "should not modify query if no offset or limit" do
        stmt = Nodes::SelectStatement.new
        sql = compile(stmt)
        sql.must_be_like "SELECT"
      end

      it "should go over table PK if no .order() or .group()" do
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.from = @table
        stmt.limit = Nodes::Limit.new(10)
        sql = compile(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY \"users\".\"id\") as _row_num FROM \"users\") as _t WHERE _row_num BETWEEN 1 AND 10"
      end

      it "caches the PK lookup for order" do
        connection = Minitest::Mock.new
        connection.expect(:primary_key, ["id"], ["users"])

        # We don't care how many times these methods are called
        def connection.quote_table_name(*); ""; end
        def connection.quote_column_name(*); ""; end

        @visitor = MSSQL.new(connection)
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.from = @table
        stmt.limit = Nodes::Limit.new(10)

        compile(stmt)
        compile(stmt)

        connection.verify
      end

      it "should use TOP for limited deletes" do
        stmt = Nodes::DeleteStatement.new
        stmt.relation = @table
        stmt.limit = Nodes::Limit.new(10)
        sql = compile(stmt)

        sql.must_be_like "DELETE TOP (10) FROM \"users\""
      end

      it "should go over query ORDER BY if .order()" do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(10)
        stmt.orders << Nodes::SqlLiteral.new("order_by")
        sql = compile(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY order_by) as _row_num) as _t WHERE _row_num BETWEEN 1 AND 10"
      end

      it "should go over query GROUP BY if no .order() and there is .group()" do
        stmt = Nodes::SelectStatement.new
        stmt.cores.first.groups << Nodes::SqlLiteral.new("group_by")
        stmt.limit = Nodes::Limit.new(10)
        sql = compile(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY group_by) as _row_num GROUP BY group_by) as _t WHERE _row_num BETWEEN 1 AND 10"
      end

      it "should use BETWEEN if both .limit() and .offset" do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(10)
        stmt.offset = Nodes::Offset.new(20)
        sql = compile(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY ) as _row_num) as _t WHERE _row_num BETWEEN 21 AND 30"
      end

      it "should use >= if only .offset" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(20)
        sql = compile(stmt)
        sql.must_be_like "SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY ) as _row_num) as _t WHERE _row_num >= 21"
      end

      it "should generate subquery for .count" do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(10)
        stmt.cores.first.projections << Nodes::Count.new("*")
        sql = compile(stmt)
        sql.must_be_like "SELECT COUNT(1) as count_id FROM (SELECT _t.* FROM (SELECT ROW_NUMBER() OVER (ORDER BY ) as _row_num) as _t WHERE _row_num BETWEEN 1 AND 10) AS subquery"
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          compile(test).must_be_like %{
            EXISTS (VALUES ("users"."name") INTERSECT VALUES ('Aaron Patterson'))
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          compile(test).must_be_like %{
            EXISTS (VALUES ("users"."first_name") INTERSECT VALUES ("users"."last_name"))
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
            NOT EXISTS (VALUES ("users"."first_name") INTERSECT VALUES ("users"."last_name"))
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
