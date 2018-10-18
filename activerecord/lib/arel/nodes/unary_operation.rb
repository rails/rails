# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UnaryOperation < Unary
      attr_reader :operator

      def initialize(operator, operand)
        super(operand)
        @operator = operator
      end
    end

    class BitwiseNot < UnaryOperation
      def initialize(operand)
        super(:~, operand)
      end
    end
  end
end
