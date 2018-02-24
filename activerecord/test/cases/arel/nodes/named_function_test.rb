# frozen_string_literal: true
require_relative '../helper'

module Arel
  module Nodes
    class TestNamedFunction < Arel::Test
      def test_construct
        function = NamedFunction.new 'omg', 'zomg'
        assert_equal 'omg', function.name
        assert_equal 'zomg', function.expressions
      end

      def test_function_alias
        function = NamedFunction.new 'omg', 'zomg'
        function = function.as('wth')
        assert_equal 'omg', function.name
        assert_equal 'zomg', function.expressions
        assert_kind_of SqlLiteral, function.alias
        assert_equal 'wth', function.alias
      end

      def test_construct_with_alias
        function = NamedFunction.new 'omg', 'zomg', 'wth'
        assert_equal 'omg', function.name
        assert_equal 'zomg', function.expressions
        assert_kind_of SqlLiteral, function.alias
        assert_equal 'wth', function.alias
      end

      def test_equality_with_same_ivars
        array = [
          NamedFunction.new('omg', 'zomg', 'wth'),
          NamedFunction.new('omg', 'zomg', 'wth')
        ]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_ivars
        array = [
          NamedFunction.new('omg', 'zomg', 'wth'),
          NamedFunction.new('zomg', 'zomg', 'wth')
        ]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
