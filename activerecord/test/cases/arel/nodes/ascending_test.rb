# frozen_string_literal: true

require_relative '../helper'

module Arel
  module Nodes
    class TestAscending < Arel::Test
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
        assert_not ascending.descending?
      end

      def test_equality_with_same_ivars
        array = [Ascending.new('zomg'), Ascending.new('zomg')]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_ivars
        array = [Ascending.new('zomg'), Ascending.new('zomg!')]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
