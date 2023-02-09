# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class SqlLiteral < String
      include Arel::Expressions
      include Arel::Predications
      include Arel::AliasPredication
      include Arel::OrderPredications

      def encode_with(coder)
        coder.scalar = self.to_s
      end

      def fetch_attribute
      end

      def +(other)
        raise ArgumentError, "Expected Arel node" unless Arel.arel_node?(other)

        Fragments.new([self, other])
      end
    end
  end
end
