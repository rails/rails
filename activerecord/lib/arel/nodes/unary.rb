# frozen_string_literal: true

module Arel
  module Nodes
    class Unary < Arel::Nodes::NodeExpression
      attr_accessor :expr
      alias :value :expr

      def initialize(expr)
        super()
        @expr = expr
      end

      def hash
        @expr.hash
      end

      def eql?(other)
        self.class == other.class &&
          self.expr == other.expr
      end
      alias :== :eql?
    end

    %w{
      Bin
      Cube
      DistinctOn
      Group
      GroupingElement
      GroupingSet
      Lateral
      Limit
      Lock
      Not
      Offset
      On
      Ordering
      RollUp
      Top
    }.each do |name|
      const_set(name, Class.new(Unary))
    end
  end
end
