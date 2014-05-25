require 'helper'
require 'arel/collectors/bind'

module Arel
  module Collectors
    class TestBindCollector < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.connection
        super
      end

      def collect node
        @visitor.accept(node, Collectors::Bind.new)
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

      def test_leaves_binds
        node = Nodes::BindParam.new 'omg'
        list = compile node
        assert_equal node, list.first
        assert_equal node.class, list.first.class
      end

      def test_adds_strings
        bv = Nodes::BindParam.new('?')
        list = compile ast_with_binds bv
        assert_operator list.length, :>, 0
        assert_equal bv, list.grep(Nodes::BindParam).first
        assert_equal bv.class, list.grep(Nodes::BindParam).first.class
      end

      def test_substitute_binds
        bv = Nodes::BindParam.new('?')
        collector = collect ast_with_binds bv

        values = collector.value

        offsets = values.map.with_index { |v,i|
          [v,i]
        }.find_all { |(v,_)| Nodes::BindParam === v }.map(&:last)

        list = collector.substitute_binds ["hello", "world"]
        assert_equal "hello", list[offsets[0]]
        assert_equal "world", list[offsets[1]]

        assert_equal 'SELECT FROM "users" WHERE "users"."age" = hello AND "users"."name" = world', list.join
      end

      def test_compile
        bv = Nodes::BindParam.new('?')
        collector = collect ast_with_binds bv

        sql = collector.compile ["hello", "world"]
        assert_equal 'SELECT FROM "users" WHERE "users"."age" = hello AND "users"."name" = world', sql
      end
    end
  end
end
