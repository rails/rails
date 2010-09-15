module Arel
  module Nodes
    ###
    # Abstract base class for all AST nodes
    class Node
      ###
      # Factory method to create a Nodes::Grouping node that has an Nodes::Or
      # node as a child.
      def or right
        Nodes::Grouping.new Nodes::Or.new(self, right)
      end

      ###
      # Factory method to create an Nodes::And node.
      def and right
        Nodes::And.new self, right
      end
    end
  end
end
