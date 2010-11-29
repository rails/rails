require 'helper'

module Arel
  module Visitors
    class TestDepthFirst < MiniTest::Unit::TestCase
      Collector = Struct.new(:calls) do
        def call object
          calls << object
        end
      end

      def setup
        @collector = Collector.new []
        @visitor = Visitors::DepthFirst.new @collector
      end

      [
        Arel::Nodes::And,
        Arel::Nodes::Assignment,
        Arel::Nodes::Between,
        Arel::Nodes::DoesNotMatch,
        Arel::Nodes::Equality,
        Arel::Nodes::GreaterThan,
        Arel::Nodes::GreaterThanOrEqual,
        Arel::Nodes::In,
        Arel::Nodes::LessThan,
        Arel::Nodes::LessThanOrEqual,
        Arel::Nodes::Matches,
        Arel::Nodes::NotEqual,
        Arel::Nodes::NotIn,
        Arel::Nodes::Or,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          binary = klass.new(:a, :b)
          @visitor.accept binary
          assert_equal [:a, :b, binary], @collector.calls
        end
      end

      [
        Arel::Attributes::Integer,
        Arel::Attributes::Float,
        Arel::Attributes::String,
        Arel::Attributes::Time,
        Arel::Attributes::Boolean,
        Arel::Attributes::Attribute
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          binary = klass.new(:a, :b)
          @visitor.accept binary
          assert_equal [:a, :b, binary], @collector.calls
        end
      end

      def test_table
        relation = Arel::Table.new(:users)
        @visitor.accept relation
        assert_equal ['users', relation], @collector.calls
      end

      def test_array
        node = Nodes::Or.new(:a, :b)
        list = [node]
        @visitor.accept list
        assert_equal [:a, :b, node, list], @collector.calls
      end

      def test_hash
        node = Nodes::Or.new(:a, :b)
        hash = { node => node }
        @visitor.accept hash
        assert_equal [:a, :b, node, :a, :b, node, hash], @collector.calls
      end

      def test_update_statement
        stmt = Nodes::UpdateStatement.new
        stmt.relation = :a
        stmt.values << :b
        stmt.wheres << :c
        stmt.orders << :d
        stmt.limit = :e

        @visitor.accept stmt
        assert_equal [:a, :b, stmt.values, :c, stmt.wheres, :d, stmt.orders,
          :e, stmt], @collector.calls
      end

      def test_select_core
        core = Nodes::SelectCore.new
        core.projections << :a
        core.froms = :b
        core.wheres << :c
        core.groups << :d
        core.having = :e

        @visitor.accept core
        assert_equal [
          :a, core.projections,
          :b,
          :c, core.wheres,
          :d, core.groups,
          :e,
          core], @collector.calls
      end

      def test_select_statement
        ss = Nodes::SelectStatement.new
        ss.cores.replace [:a]
        ss.orders << :b
        ss.limit = :c
        ss.lock = :d
        ss.offset = :e

        @visitor.accept ss
        assert_equal [
          :a, ss.cores,
          :b, ss.orders,
          :c,
          :d,
          :e,
          ss], @collector.calls
      end
    end
  end
end
