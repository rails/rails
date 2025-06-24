# frozen_string_literal: true

require_relative "../helper"
require "arel/collectors/substitute_binds"
require "arel/collectors/sql_string"

module Arel
  module Collectors
    class TestSubstituteBindCollector < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.lease_connection
        super
      end

      def ast_with_binds
        table = Table.new(:users)
        manager = Arel::SelectManager.new table
        manager.where(table[:age].eq(Nodes::BindParam.new("hello")))
        manager.where(table[:name].eq(Nodes::BindParam.new("world")))
        manager.ast
      end

      def compile(node, quoter)
        collector = Collectors::SubstituteBinds.new(quoter, Collectors::SQLString.new)
        @visitor.accept(node, collector).value
      end

      def test_compile
        quoter = Object.new
        def quoter.quote(val)
          val.to_s
        end
        sql = compile(ast_with_binds, quoter)
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = hello AND "users"."name" = world', sql
      end

      def test_quoting_is_delegated_to_quoter
        quoter = Object.new
        def quoter.quote(val)
          val.inspect
        end
        sql = compile(ast_with_binds, quoter)
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = "hello" AND "users"."name" = "world"', sql
      end
    end
  end
end
