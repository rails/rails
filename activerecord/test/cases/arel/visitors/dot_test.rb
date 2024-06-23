# frozen_string_literal: true

require_relative "../helper"
require "active_model/attribute"

module Arel
  module Visitors
    class TestDot < Arel::Test
      def setup
        @visitor = Visitors::Dot.new
      end

      def assert_edge(edge_name, dot_string)
        assert_match(/->.*label="#{edge_name}"/, dot_string)
      end

      # functions
      [
        Nodes::Sum,
        Nodes::Exists,
        Nodes::Max,
        Nodes::Min,
        Nodes::Avg,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          op = klass.new(:a, "z")
          @visitor.accept op, Collectors::PlainString.new
          pass
        end
      end

      def test_named_function
        func = Nodes::NamedFunction.new "omg", "omg"
        @visitor.accept func, Collectors::PlainString.new
        pass
      end

      # unary ops
      [
        Arel::Nodes::Not,
        Arel::Nodes::Group,
        Arel::Nodes::On,
        Arel::Nodes::Grouping,
        Arel::Nodes::Offset,
        Arel::Nodes::Ordering,
        Arel::Nodes::UnqualifiedColumn,
        Arel::Nodes::ValuesList,
        Arel::Nodes::Limit,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          op = klass.new(:a)
          @visitor.accept op, Collectors::PlainString.new
          pass
        end
      end

      # binary ops
      [
        Arel::Nodes::Assignment,
        Arel::Nodes::Between,
        Arel::Nodes::DoesNotMatch,
        Arel::Nodes::Equality,
        Arel::Nodes::GreaterThan,
        Arel::Nodes::GreaterThanOrEqual,
        Arel::Nodes::In,
        Arel::Nodes::LessThan,
        Arel::Nodes::LessThanOrEqual,
        Arel::Nodes::Matches,
        Arel::Nodes::NotEqual,
        Arel::Nodes::NotIn,
        Arel::Nodes::TableAlias,
        Arel::Nodes::As,
        Arel::Nodes::JoinSource,
        Arel::Nodes::Casted,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          binary = klass.new(:a, :b)
          @visitor.accept binary, Collectors::PlainString.new
          pass
        end
      end

      # nary ops
      [
        Arel::Nodes::And,
        Arel::Nodes::Or,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          binary = klass.new([:a, :b])
          @visitor.accept binary, Collectors::PlainString.new
          pass
        end
      end

      def test_Arel_Nodes_BindParam
        node = Arel::Nodes::BindParam.new(1)
        collector = Collectors::PlainString.new
        assert_match '[label="<f0>Arel::Nodes::BindParam"]', @visitor.accept(node, collector).value
      end

      def test_ActiveModel_Attribute
        node = ActiveModel::Attribute.with_cast_value("LIMIT", 1, nil)
        collector = Collectors::PlainString.new
        assert_match '[label="<f0>ActiveModel::Attribute::WithCastValue"]', @visitor.accept(node, collector).value
      end

      def test_Arel_Nodes_CurrentRow
        node = Arel::Nodes::CurrentRow.new
        collector = Collectors::PlainString.new
        assert_match '[label="<f0>Arel::Nodes::CurrentRow"]', @visitor.accept(node, collector).value
      end

      def test_Arel_Nodes_Distinct
        node = Arel::Nodes::Distinct.new
        collector = Collectors::PlainString.new
        assert_match '[label="<f0>Arel::Nodes::Distinct"]', @visitor.accept(node, collector).value
      end

      def test_Arel_Nodes_Case_and_friends
        foo = Arel::Nodes.build_quoted("foo")
        node = Arel::Nodes::Case.new(foo)
        node.conditions = [Arel::Nodes::When.new(foo, Arel::Nodes.build_quoted(1))]
        node.default = Arel::Nodes::Else.new(Arel::Nodes.build_quoted(0))

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::Case"]', dot
        assert_edge("case", dot)
        assert_edge("conditions", dot)
        assert_edge("default", dot)
        assert_match '[label="<f0>Arel::Nodes::When"]', dot
        assert_match '[label="<f0>Arel::Nodes::Else"]', dot
        assert_match '[label="<f0>Arel::Nodes::Else"]', dot
      end

      def test_Arel_Nodes_InfixOperation
        node = Arel::Nodes::InfixOperation.new("&&", Arel::Nodes.build_quoted(1), Arel::Nodes.build_quoted(2))

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::InfixOperation"]', dot
        assert_edge("operator", dot)
        assert_edge("left", dot)
        assert_edge("right", dot)
      end

      def test_Arel_Nodes_RegExp
        table = Table.new(:users)
        node = Arel::Nodes::Regexp.new(table[:name], Nodes.build_quoted("foo%"))

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::Regexp"]', dot
        assert_edge("left", dot)
        assert_edge("right", dot)
        assert_edge("case_sensitive", dot)
      end

      def test_Arel_Nodes_NotRegExp
        table = Table.new(:users)
        node = Arel::Nodes::NotRegexp.new(table[:name], Nodes.build_quoted("foo%"))

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::NotRegexp"]', dot
        assert_edge("left", dot)
        assert_edge("right", dot)
        assert_edge("case_sensitive", dot)
      end

      def test_Arel_Nodes_UnaryOperation
        node = Arel::Nodes::UnaryOperation.new(:-, 1)

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::UnaryOperation"]', dot
        assert_edge("operator", dot)
        assert_edge("expr", dot)
      end

      def test_Arel_Nodes_With
        node = Arel::Nodes::With.new(["query1", "query2", "query3"])

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::With"]', dot
        assert_edge("0", dot)
        assert_edge("1", dot)
        assert_edge("2", dot)
      end

      def test_Arel_Nodes_SelectCore
        node = Arel::Nodes::SelectCore.new

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::SelectCore"]', dot
        assert_edge("source", dot)
        assert_edge("projections", dot)
        assert_edge("wheres", dot)
        assert_edge("windows", dot)
        assert_edge("groups", dot)
        assert_edge("comment", dot)
        assert_edge("havings", dot)
        assert_edge("set_quantifier", dot)
        assert_edge("optimizer_hints", dot)
      end

      def test_Arel_Nodes_SelectStatement
        node = Arel::Nodes::SelectStatement.new

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::SelectStatement"]', dot
        assert_edge("cores", dot)
        assert_edge("limit", dot)
        assert_edge("orders", dot)
        assert_edge("offset", dot)
        assert_edge("lock", dot)
        assert_edge("with", dot)
      end

      def test_Arel_Nodes_InsertStatement
        node = Arel::Nodes::InsertStatement.new

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::InsertStatement"]', dot
        assert_edge("relation", dot)
        assert_edge("columns", dot)
        assert_edge("values", dot)
        assert_edge("select", dot)
      end

      def test_Arel_Nodes_UpdateStatement
        node = Arel::Nodes::UpdateStatement.new

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::UpdateStatement"]', dot
        assert_edge("relation", dot)
        assert_edge("wheres", dot)
        assert_edge("values", dot)
        assert_edge("orders", dot)
        assert_edge("limit", dot)
        assert_edge("offset", dot)
        assert_edge("key", dot)
      end

      def test_Arel_Nodes_DeleteStatement
        node = Arel::Nodes::DeleteStatement.new

        dot = @visitor.accept(node, Arel::Collectors::PlainString.new).value

        assert_match '[label="<f0>Arel::Nodes::DeleteStatement"]', dot
        assert_edge("relation", dot)
        assert_edge("wheres", dot)
        assert_edge("orders", dot)
        assert_edge("limit", dot)
        assert_edge("offset", dot)
        assert_edge("key", dot)
      end
    end
  end
end
