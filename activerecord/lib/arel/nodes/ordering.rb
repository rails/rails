# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Ordering < Unary
      def nulls_first
        NullsFirst.new(self)
      end

      def nulls_last
        NullsLast.new(self)
      end
    end

    class NullsFirst < Ordering
      def reverse
        NullsLast.new(expr.reverse)
      end
    end

    class NullsLast < Ordering
      def reverse
        NullsFirst.new(expr.reverse)
      end
    end
  end
end
