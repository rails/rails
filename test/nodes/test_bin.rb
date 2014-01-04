require 'helper'

module Arel
  module Nodes
    class TestBin < Minitest::Test
      def test_new
        assert Arel::Nodes::Bin.new('zomg')
      end

      def test_default_to_sql
        viz  = Arel::Visitors::ToSql.new Table.engine.connection_pool
        node = Arel::Nodes::Bin.new(Arel.sql('zomg'))
        assert_equal 'zomg', viz.accept(node)
      end

      def test_mysql_to_sql
        viz  = Arel::Visitors::MySQL.new Table.engine.connection_pool
        node = Arel::Nodes::Bin.new(Arel.sql('zomg'))
        assert_equal 'BINARY zomg', viz.accept(node)
      end

      def test_equality_with_same_ivars
        array = [Bin.new('zomg'), Bin.new('zomg')]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_ivars
        array = [Bin.new('zomg'), Bin.new('zomg!')]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
