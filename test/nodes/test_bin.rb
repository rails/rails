require 'helper'

module Arel
  module Nodes
    class TestBin < MiniTest::Unit::TestCase
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
    end
  end
end
