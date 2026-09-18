# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UnaryOperation < Unary
      attr_reader :operator

      def initialize(operator, operand)
        super(operand)
        @operator = operator
      end

      def hash
        super ^ @operator.hash
      end

      def eql?(other)
        super && self.operator == other.operator
      end
      alias :== :eql?
    end

    class BitwiseNot < UnaryOperation
      def initialize(operand)
        super(:~, operand)
      end
    end
  end
end
