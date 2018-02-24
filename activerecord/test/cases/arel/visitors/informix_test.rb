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
    end
  end
end
