module Arel
  module Nodes
    class UnqualifiedColumn < Arel::Nodes::Unary
      alias :attribute :expr
      alias :attribute= :expr=

      def column
        @expr.column
      end

      def name
        @expr.name
      end
    end
  end
end
