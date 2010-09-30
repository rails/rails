module Arel
  module Nodes
    class Ordering < Arel::Nodes::Node
      attr_accessor :expr, :direction

      def initialize expression, direction = :asc
        @expr, @direction = expression, direction
      end

      def ascending?
        direction == :asc
      end

      def descending?
        direction == :desc
      end
    end
  end
end
