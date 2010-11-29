module Arel
  module Nodes
    class Ordering < Arel::Nodes::Binary
      alias :expr :left
      alias :direction :right

      def initialize expr, direction = :asc
        super
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
