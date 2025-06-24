# frozen_string_literal: true

require_relative "helper"

module Arel
  module FactoryMethods
    class TestFactoryMethods < Arel::Test
      class Factory
        include Arel::FactoryMethods
      end

      def setup
        @factory = Factory.new
      end

      def test_create_join
        join = @factory.create_join :one, :two
        assert_kind_of Nodes::Join, join
        assert_equal :two, join.right
      end

      def test_create_table_alias
        table_alias = @factory.create_table_alias :one, :two
        assert_kind_of Nodes::TableAlias, table_alias
        assert_equal :two, table_alias.right
      end

      def test_create_and
        and_node = @factory.create_and ["foo", "bar"]
        assert_instance_of Nodes::And, and_node
        assert_equal ["foo", "bar"], and_node.children
      end

      def test_create_string_join
        join = @factory.create_string_join "foo"
        assert_kind_of Arel::Nodes::StringJoin, join
        assert_equal "foo", join.left
      end

      def test_grouping
        grouping = @factory.grouping :one
        assert_instance_of Nodes::Grouping, grouping
        assert_equal :one, grouping.expr
      end

      def test_create_on
        on = @factory.create_on :one
        assert_instance_of Nodes::On, on
        assert_equal :one, on.expr
      end

      def test_create_true
        true_node = @factory.create_true
        assert_instance_of Nodes::True, true_node
      end

      def test_create_false
        false_node = @factory.create_false
        assert_instance_of Nodes::False, false_node
      end

      def test_lower
        lower = @factory.lower :one
        assert_instance_of Nodes::NamedFunction, lower
        assert_equal "LOWER", lower.name
        assert_equal [:one], lower.expressions.map(&:expr)
      end

      def test_coalesce
        relation = Table.new(:users)
        field_node = relation[:active]
        coalesce = @factory.coalesce field_node, 0
        assert_instance_of Nodes::NamedFunction, coalesce
        assert_equal "COALESCE", coalesce.name
        assert_equal [field_node, 0], coalesce.expressions
      end

      def test_cast
        relation = Table.new(:users)
        field_node = relation[:active]
        cast = @factory.cast field_node, "boolean"
        assert_instance_of Nodes::NamedFunction, cast
        assert_equal "CAST", cast.name
        as_node = cast.expressions.first
        assert_instance_of Nodes::As, as_node
        assert_equal field_node, as_node.left
        assert_equal "boolean", as_node.right
      end
    end
  end
end
