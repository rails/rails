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
    end
  end
end
