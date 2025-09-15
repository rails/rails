# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class SqliteTest < Arel::Spec
      before do
        @visitor = SQLite.new Table.engine.lease_connection
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it "defaults limit to -1" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        sql = @visitor.accept(stmt, Collectors::SQLString.new).value
        _(sql).must_be_like "SELECT LIMIT -1 OFFSET 1"
      end

      it "does not support locking" do
        node = Nodes::Lock.new(Arel.sql("FOR UPDATE"))
        assert_equal "", @visitor.accept(node, Collectors::SQLString.new).value
      end

      describe "Nodes::IsNotDistinctFrom" do
        it "should construct a valid generic SQL statement" do
          test = Table.new(:users)[:name].is_not_distinct_from "Aaron Patterson"
          _(compile(test)).must_be_like %{
            "users"."name" IS 'Aaron Patterson'
          }
        end

        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_not_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" IS "users"."last_name"
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsNotDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NULL }
        end
      end

      describe "Nodes::IsDistinctFrom" do
        it "should handle column names on both sides" do
          test = Table.new(:users)[:first_name].is_distinct_from Table.new(:users)[:last_name]
          _(compile(test)).must_be_like %{
            "users"."first_name" IS NOT "users"."last_name"
          }
        end

        it "should handle nil" do
          @table = Table.new(:users)
          val = Nodes.build_quoted(nil, @table[:active])
          sql = compile Nodes::IsDistinctFrom.new(@table[:name], val)
          _(sql).must_be_like %{ "users"."name" IS NOT NULL }
        end
      end

      describe "ValuesTable" do
        before do
          @rows = [[1, "one"], [2, "two"]]
          @column_types = [FakeRecord::Column.new("id", :integer), FakeRecord::Column.new("name", :string)]
        end

        it "outputs no column aliases" do
          values_table = Arel::ValuesTable.new(:data, @rows)

          _(compile(values_table)).must_be_like %{
            (VALUES (1, 'one'), (2, 'two')) "data"
          }
        end

        it "outputs column aliases as subquery if given" do
          values_table = Arel::ValuesTable.new(:data, @rows, column_aliases: %i[id name])

          _(compile(values_table)).must_be_like %{
            (SELECT "column1" AS "id", "column2" AS "name" FROM (VALUES (1, 'one'), (2, 'two'))) "data"
          }
        end

        it "ignores column_types" do
          values_table = Arel::ValuesTable.new(:data, @rows, column_types: @column_types)

          _(compile(values_table)).must_be_like %{
            (VALUES (1, 'one'), (2, 'two')) "data"
          }
        end
      end
    end
  end
end
