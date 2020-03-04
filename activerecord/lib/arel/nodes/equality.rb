# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Equality < Arel::Nodes::Binary
      def operator; :== end
      alias :operand1 :left
      alias :operand2 :right

      def invert
        Arel::Nodes::NotEqual.new(left, right)
      end
    end

    class IsDistinctFrom < Equality
      def invert
        Arel::Nodes::IsNotDistinctFrom.new(left, right)
      end
    end

    class IsNotDistinctFrom < Equality
      def invert
        Arel::Nodes::IsDistinctFrom.new(left, right)
      end
    end
  end
end
