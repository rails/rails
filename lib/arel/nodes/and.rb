module Arel
  module Nodes
    class And < Arel::Nodes::Node
      attr_reader :children

      def initialize children, right = nil
        super()
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

      def hash
        children.hash
      end

      def eql? other
        self.class == other.class &&
          self.children == other.children
      end
      alias :== :eql?
    end
  end
end
