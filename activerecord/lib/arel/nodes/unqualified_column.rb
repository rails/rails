# frozen_string_literal: true

module Arel
  module Nodes
    class UnqualifiedColumn < Arel::Nodes::Unary
      alias :attribute :expr
      alias :attribute= :expr=

      def relation
        @expr.relation
      end

      def column
        @expr.column
      end

      def name
        @expr.name
      end
    end
  end
end
