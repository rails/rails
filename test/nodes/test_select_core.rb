require 'helper'

module Arel
  module Nodes
    class TestSelectCore < MiniTest::Unit::TestCase
      def test_clone
        core = Arel::Nodes::SelectCore.new
        core.froms       = %w[a b c]
        core.projections = %w[d e f]
        core.wheres      = %w[g h i]

        dolly = core.clone

        dolly.froms.must_equal core.froms
        dolly.projections.must_equal core.projections
        dolly.wheres.must_equal core.wheres

        dolly.froms.wont_be_same_as core.froms
        dolly.projections.wont_be_same_as core.projections
        dolly.wheres.wont_be_same_as core.wheres
      end

      def test_set_quantifier
        core = Arel::Nodes::SelectCore.new
        core.set_quantifier = Arel::Nodes::Distinct.new
        viz = Arel::Visitors::ToSql.new Table.engine.connection_pool
        assert_match 'DISTINCT', viz.accept(core)
      end
    end
  end
end
