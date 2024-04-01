# frozen_string_literal: true

require_relative "../helper"

require "arel/collectors/bind"
require "arel/collectors/composite"

module Arel
  module Collectors
    class TestComposite < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.lease_connection
        super
      end

      def collect(node)
        sql_collector = Collectors::SQLString.new
        bind_collector = Collectors::Bind.new
        collector = Collectors::Composite.new(sql_collector, bind_collector)
        @visitor.accept(node, collector)
      end

      def compile(node)
        collect(node).value
      end

      def ast_with_binds(bvs)
        table = Table.new(:users)
        manager = Arel::SelectManager.new table
        manager.where(table[:age].eq(Nodes::BindParam.new(bvs.shift)))
        manager.where(table[:name].eq(Nodes::BindParam.new(bvs.shift)))
        manager.ast
      end

      def test_composite_collector_performs_multiple_collections_at_once
        sql, binds = compile(ast_with_binds(["hello", "world"]))
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = ? AND "users"."name" = ?', sql
        assert_equal ["hello", "world"], binds

        sql, binds = compile(ast_with_binds(["hello2", "world3"]))
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = ? AND "users"."name" = ?', sql
        assert_equal ["hello2", "world3"], binds
      end

      def test_retryable_on_composite_collector_propagates
        sql_collector = Collectors::SQLString.new
        bind_collector = Collectors::Bind.new
        collector = Collectors::Composite.new(sql_collector, bind_collector)
        collector.retryable = true

        assert sql_collector.retryable
        assert bind_collector.retryable
      end
    end
  end
end
