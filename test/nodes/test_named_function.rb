require 'helper'

module Arel
  module Nodes
    class TestNamedFunction < MiniTest::Unit::TestCase
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
    end
  end
end
