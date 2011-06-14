require 'helper'

module Arel
  module Nodes
    class TestAscending < MiniTest::Unit::TestCase
      def test_construct
        ascending = Ascending.new 'zomg'
        assert_equal 'zomg', ascending.expr
      end

      def test_reverse
        ascending = Ascending.new 'zomg'
        descending = ascending.reverse
        assert_kind_of Descending, descending
        assert_equal ascending.expr, descending.expr
      end

      def test_direction
        ascending = Ascending.new 'zomg'
        assert_equal :asc, ascending.direction
      end

      def test_ascending?
        ascending = Ascending.new 'zomg'
        assert ascending.ascending?
      end

      def test_descending?
        ascending = Ascending.new 'zomg'
        assert !ascending.descending?
      end
    end
  end
end
