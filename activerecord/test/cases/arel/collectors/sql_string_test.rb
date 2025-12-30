# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Collectors
    class TestSqlString < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.lease_connection
        super
      end

      def collect(node)
        @visitor.accept(node, Collectors::SQLString.new)
      end

      def compile(node)
        collect(node).value
      end

      def ast_with_binds
        table = Table.new(:users)
        manager = Arel::SelectManager.new table
        manager.where(table[:age].eq(Nodes::BindParam.new("hello")))
        manager.where(table[:name].eq(Nodes::BindParam.new("world")))
        manager.ast
      end

      def test_compile
        sql = compile(ast_with_binds)
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = ? AND "users"."name" = ?', sql
      end

      def test_returned_sql_uses_utf8_encoding
        sql = compile(ast_with_binds)
        assert_equal sql.encoding, Encoding::UTF_8
      end
    end
  end
end
