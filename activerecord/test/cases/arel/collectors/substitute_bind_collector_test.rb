# frozen_string_literal: true

require_relative "../helper"
require "arel/collectors/substitute_binds"

module Arel
  module Collectors
    class TestSubstituteBindCollector < Arel::Test
      setup do
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.lease_connection
      end

      def ast_with_binds
        table = Table.new(name: :users)
        manager = Arel::SelectManager.new table
        manager.where(table[:age].eq(Nodes::BindParam.new("hello")))
        manager.where(table[:name].eq(Nodes::BindParam.new("world")))
        manager.ast
      end

      def compile(node, quoter)
        collector = Collectors::SubstituteBinds.new(quoter)
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

      def test_default_collector_buffers_sql
        collector = Collectors::SubstituteBinds.new(@conn.lease_connection)

        assert_equal "", collector.value
        assert_same collector, collector << "VALUES ("
        assert_same collector, collector.add_bind("hello")
        assert_same collector, collector << ", "
        assert_same collector, collector.add_binds(["world", "again"])
        assert_same collector, collector << ")"
        assert_equal "VALUES ('hello', 'world', 'again')", collector.value
      end

      def test_default_collectors_have_independent_buffers
        first = Collectors::SubstituteBinds.new(@conn.lease_connection)
        second = Collectors::SubstituteBinds.new(@conn.lease_connection)

        (first << "SELECT 1").value.freeze

        assert_equal "SELECT 2", (second << "SELECT 2").value
      end

      def test_supplied_collector_receives_sql_fragments
        delegate = Struct.new(:value).new([])
        def delegate.<<(sql)
          value << sql
        end

        collector = Collectors::SubstituteBinds.new(@conn.lease_connection, delegate)

        assert_same collector, collector << "VALUES ("
        assert_same collector, collector.add_bind("hello")
        assert_same collector, collector << ", "
        assert_same collector, collector.add_binds(["world", "again"])
        assert_same collector, collector << ")"
        assert_same delegate.value, collector.value
        assert_equal ["VALUES (", "'hello'", ", ", "'world', 'again'", ")"], collector.value
      end
    end
  end
end
