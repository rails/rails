require 'helper'
require 'arel/collectors/bind'

module Arel
  module Collectors
    class TestSqlString < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.connection
        super
      end

      def collect node
        @visitor.accept(node, Collectors::SQLString.new)
      end

      def compile node
        collect(node).value
      end

      def ast_with_binds bv
        table = Table.new(:users)
        manager = Arel::SelectManager.new Table.engine, table
        manager.where(table[:age].eq(bv))
        manager.where(table[:name].eq(bv))
        manager.ast
      end

      def test_compile
        bv = Nodes::BindParam.new('?')
        collector = collect ast_with_binds bv

        sql = collector.compile ["hello", "world"]
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = ? AND "users"."name" = ?', sql
      end
    end
  end
end
