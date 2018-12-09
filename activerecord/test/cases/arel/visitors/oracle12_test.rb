# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Visitors
    class Oracle12Test < Arel::Spec
      before do
        @visitor = Oracle12.new Table.engine.connection
        @table = Table.new(:users)
      end

      def compile(node)
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it "modified except to be minus" do
        left = Nodes::SqlLiteral.new("SELECT * FROM users WHERE age > 10")
        right = Nodes::SqlLiteral.new("SELECT * FROM users WHERE age > 20")
        sql = compile Nodes::Except.new(left, right)
        sql.must_be_like %{
          ( SELECT * FROM users WHERE age > 10 MINUS SELECT * FROM users WHERE age > 20 )
        }
      end

      it "generates select options offset then limit" do
        stmt = Nodes::SelectStatement.new
        stmt.offset = Nodes::Offset.new(1)
        stmt.limit = Nodes::Limit.new(10)
        sql = compile(stmt)
        sql.must_be_like "SELECT OFFSET 1 ROWS FETCH FIRST 10 ROWS ONLY"
      end

      describe "locking" do
        it "generates ArgumentError if limit and lock are used" do
          stmt = Nodes::SelectStatement.new
          stmt.limit = Nodes::Limit.new(10)
          stmt.lock = Nodes::Lock.new(Arel.sql("FOR UPDATE"))
          assert_raises ArgumentError do
            compile(stmt)
          end
        end

        it "defaults to FOR UPDATE when locking" do
          node = Nodes::Lock.new(Arel.sql("FOR UPDATE"))
          compile(node).must_be_like "FOR UPDATE"
        end
      end

      describe "Nodes::BindParam" do
        it "increments each bind param" do
          query = @table[:name].eq(Arel::Nodes::BindParam.new(1))
            .and(@table[:id].eq(Arel::Nodes::BindParam.new(1)))
          compile(query).must_be_like %{
            "users"."name" = :a1 AND "users"."id" = :a2
          }
        end
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
