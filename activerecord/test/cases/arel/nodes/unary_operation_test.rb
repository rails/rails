# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class TestUnaryOperation < Arel::Test
      def test_construct
        operation = UnaryOperation.new :-, 1
        assert_equal :-, operation.operator
        assert_equal 1, operation.expr
      end

      def test_operation_alias
        operation = UnaryOperation.new :-, 1
        aliaz = operation.as("zomg")
        assert_kind_of As, aliaz
        assert_equal operation, aliaz.left
        assert_equal "zomg", aliaz.right
      end

      def test_operation_ordering
        operation = UnaryOperation.new :-, 1
        ordering = operation.desc
        assert_kind_of Descending, ordering
        assert_equal operation, ordering.expr
        assert ordering.descending?
      end

      def test_equality_with_same_ivars
        array = [UnaryOperation.new(:-, 1), UnaryOperation.new(:-, 1)]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_ivars
        array = [UnaryOperation.new(:-, 1), UnaryOperation.new(:-, 2)]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
