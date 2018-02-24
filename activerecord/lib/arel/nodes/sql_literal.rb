# frozen_string_literal: true

module Arel
  module Nodes
    class SqlLiteral < String
      include Arel::Expressions
      include Arel::Predications
      include Arel::AliasPredication
      include Arel::OrderPredications

      def encode_with(coder)
        coder.scalar = self.to_s
      end
    end
  end
end
