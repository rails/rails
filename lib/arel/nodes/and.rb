module Arel
  module Nodes
    class And < Arel::Nodes::Node
      attr_reader :children

      def initialize children, right = nil
        unless Array === children
          warn "(#{caller.first}) AND nodes should be created with a list"
          children = [children, right]
        end
        @children = children
      end

      def left
        children.first
      end

      def right
        children[1]
      end
    end
  end
end
