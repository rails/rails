# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Collectors
    class TestSqlString < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.connection
        super
      end

      def collect(node)
        @visitor.accept(node, Collectors::SQLString.new)
      end

      def compile(node)
        collect(node).value
      end

      def ast_with_binds(bv)
        table = Table.new(:users)
        manager = Arel::SelectManager.new table
        manager.where(table[:age].eq(bv))
        manager.where(table[:name].eq(bv))
        manager.ast
      end

      def test_compile
        bv = Nodes::BindParam.new(1)
        collector = collect ast_with_binds bv

        sql = collector.compile ["hello", "world"]
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = ? AND "users"."name" = ?', sql
      end

      def test_returned_sql_uses_utf8_encoding
        bv = Nodes::BindParam.new(1)
        collector = collect ast_with_binds bv

        sql = collector.compile ["hello", "world"]
        assert_equal sql.encoding, Encoding::UTF_8
      end
    end
  end
end
