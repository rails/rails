require 'helper'

module Arel
  module Visitors
    class TestDot < MiniTest::Unit::TestCase
      def setup
        @visitor = Visitors::Dot.new
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
        end
      end
    end
  end
end
