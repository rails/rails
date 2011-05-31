module Arel
  module Nodes
    class True < Arel::Nodes::Node
      def not
        False.new
      end

      def or right
        self
      end

      def and right
        right
      end
    end
  end
end
