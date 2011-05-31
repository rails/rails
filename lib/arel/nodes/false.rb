module Arel
  module Nodes
    class False < Arel::Nodes::Node
      def not
        True.new
      end

      def or right
        right
      end

      def and right
        self
      end
    end
  end
end
