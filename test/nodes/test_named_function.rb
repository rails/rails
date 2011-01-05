require 'helper'

module Arel
  module Nodes
    class TestNamedFunction < MiniTest::Unit::TestCase
      def test_construct
        function = NamedFunction.new 'omg', 'zomg'
        assert_equal 'omg', function.name
        assert_equal 'zomg', function.expressions
      end
    end
  end
end
