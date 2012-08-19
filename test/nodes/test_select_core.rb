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

      def test_equality_with_same_ivars
        core1 = SelectCore.new
        core1.froms       = %w[a b c]
        core1.projections = %w[d e f]
        core1.wheres      = %w[g h i]
        core1.groups      = %w[j k l]
        core1.windows     = %w[m n o]
        core1.having      = %w[p q r]
        core2 = SelectCore.new
        core2.froms       = %w[a b c]
        core2.projections = %w[d e f]
        core2.wheres      = %w[g h i]
        core2.groups      = %w[j k l]
        core2.windows     = %w[m n o]
        core2.having      = %w[p q r]
        array = [core1, core2]
        assert_equal 1, array.uniq.size
      end

      def test_inequality_with_different_ivars
        core1 = SelectCore.new
        core1.froms       = %w[a b c]
        core1.projections = %w[d e f]
        core1.wheres      = %w[g h i]
        core1.groups      = %w[j k l]
        core1.windows     = %w[m n o]
        core1.having      = %w[p q r]
        core2 = SelectCore.new
        core2.froms       = %w[a b c]
        core2.projections = %w[d e f]
        core2.wheres      = %w[g h i]
        core2.groups      = %w[j k l]
        core2.windows     = %w[m n o]
        core2.having      = %w[l o l]
        array = [core1, core2]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
