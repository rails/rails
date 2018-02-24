# frozen_string_literal: true
require_relative '../helper'

module Arel
  module Visitors
    class IbmDbTest < Arel::Spec
      before do
        @visitor = IBM_DB.new Table.engine.connection
      end

      def compile node
        @visitor.accept(node, Collectors::SQLString.new).value
      end

      it 'uses FETCH FIRST n ROWS to limit results' do
        stmt = Nodes::SelectStatement.new
        stmt.limit = Nodes::Limit.new(1)
        sql = compile(stmt)
        sql.must_be_like "SELECT FETCH FIRST 1 ROWS ONLY"
      end

      it 'uses FETCH FIRST n ROWS in updates with a limit' do
        table = Table.new(:users)
        stmt = Nodes::UpdateStatement.new
        stmt.relation = table
        stmt.limit = Nodes::Limit.new(Nodes.build_quoted(1))
        stmt.key = table[:id]
        sql = compile(stmt)
        sql.must_be_like "UPDATE \"users\" WHERE \"users\".\"id\" IN (SELECT \"users\".\"id\" FROM \"users\" FETCH FIRST 1 ROWS ONLY)"
      end

    end
  end
end
