# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Equality < Arel::Nodes::Binary
      def operator; :== end

      def equality?; true; end

      def invert
        Arel::Nodes::NotEqual.new(left, right)
      end

      def fetch_attribute
        if left.is_a?(Arel::Attributes::Attribute)
          yield left
        elsif right.is_a?(Arel::Attributes::Attribute)
          yield right
        end
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
