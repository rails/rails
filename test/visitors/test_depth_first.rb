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

      def test_raises_with_object
        assert_raises(TypeError) do
          @visitor.accept(Object.new)
        end
      end


      # unary ops
      [
        Arel::Nodes::Not,
        Arel::Nodes::Group,
        Arel::Nodes::On,
        Arel::Nodes::Grouping,
        Arel::Nodes::Offset,
        Arel::Nodes::Having,
        Arel::Nodes::UnqualifiedColumn,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          op = klass.new(:a)
          @visitor.accept op
          assert_equal [:a, op], @collector.calls
        end
      end

      # functions
      [
        Arel::Nodes::Exists,
        Arel::Nodes::Avg,
        Arel::Nodes::Min,
        Arel::Nodes::Max,
        Arel::Nodes::Sum,
      ].each do |klass|
        define_method("test_#{klass.name.gsub('::', '_')}") do
          func = klass.new(:a, :b)
          @visitor.accept func
          assert_equal [:a, :b, func], @collector.calls
        end
      end

      def test_lock
        lock = Nodes::Lock.new
        @visitor.accept lock
        assert_equal [lock], @collector.calls
      end

      def test_count
        count = Nodes::Count.new :a, :b, :c
        @visitor.accept count
        assert_equal [:a, :c, :b, count], @collector.calls
      end

      def test_inner_join
        join = Nodes::InnerJoin.new :a, :b, :c
        @visitor.accept join
        assert_equal [:a, :b, :c, join], @collector.calls
      end

      def test_outer_join
        join = Nodes::OuterJoin.new :a, :b, :c
        @visitor.accept join
        assert_equal [:a, :b, :c, join], @collector.calls
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
        Arel::Nodes::StringJoin,
        Arel::Nodes::TableAlias,
        Arel::Nodes::Values,
        Arel::Nodes::As,
        Arel::Nodes::DeleteStatement,
        Arel::Nodes::Ordering,
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

      def test_insert_statement
        stmt = Nodes::InsertStatement.new
        stmt.relation = :a
        stmt.columns << :b
        stmt.values = :c

        @visitor.accept stmt
        assert_equal [:a, :b, stmt.columns, :c, stmt], @collector.calls
      end

      def test_node
        node = Nodes::Node.new
        @visitor.accept node
        assert_equal [node], @collector.calls
      end
    end
  end
end
