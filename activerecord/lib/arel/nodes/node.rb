# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    ###
    # Abstract base class for all AST nodes
    class Node
      include Arel::FactoryMethods

      ###
      # Factory method to create a Nodes::Not node that has the recipient of
      # the caller as a child.
      def not
        Nodes::Not.new self
      end

      ###
      # Factory method to create a Nodes::Grouping node that has an Nodes::Or
      # node as a child.
      def or(right)
        Nodes::Grouping.new Nodes::Or.new(self, right)
      end

      ###
      # Factory method to create an Nodes::And node.
      def and(right)
        Nodes::And.new [self, right]
      end

      def invert
        Arel::Nodes::Not.new(self)
      end

      # FIXME: this method should go away.  I don't like people calling
      # to_sql on non-head nodes.  This forces us to walk the AST until we
      # can find a node that has a "relation" member.
      #
      # Maybe we should just use `Table.engine`?  :'(
      def to_sql(engine = Table.engine)
        collector = Arel::Collectors::SQLString.new
        collector = engine.connection.visitor.accept self, collector
        collector.value
      end

      def fetch_attribute
      end

      def equality?; false; end
    end
  end
end
