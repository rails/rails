# frozen_string_literal: true
module Arel
  module Nodes

    class UnaryOperation < Unary
      include Arel::Expressions
      include Arel::Predications
      include Arel::OrderPredications
      include Arel::AliasPredication
      include Arel::Math

      attr_reader :operator

      def initialize operator, operand
        super(operand)
        @operator = operator
      end
    end

    class BitwiseNot < UnaryOperation
      def initialize operand
        super(:~, operand)
      end
    end
  end
end