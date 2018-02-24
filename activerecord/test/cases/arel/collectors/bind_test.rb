# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Collectors
    class TestBind < Arel::Test
      def setup
        @conn = FakeRecord::Base.new
        @visitor = Visitors::ToSql.new @conn.connection
        super
      end

      def collect(node)
        @visitor.accept(node, Collectors::Bind.new)
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

      def test_compile_gathers_all_bind_params
        binds = compile(ast_with_binds(["hello", "world"]))
        assert_equal ["hello", "world"], binds

        binds = compile(ast_with_binds(["hello2", "world3"]))
        assert_equal ["hello2", "world3"], binds
      end
    end
  end
end
