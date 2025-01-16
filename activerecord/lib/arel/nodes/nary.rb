# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Nary < Arel::Nodes::NodeExpression
      attr_reader :children

      def initialize(children)
        super()
        @children = children
      end

      def left
        children.first
      end

      def right
        children[1]
      end

      def fetch_attribute(&block)
        children.any? && children.all? { |child| child.fetch_attribute(&block) }
      end

      def hash
        [self.class, children].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.children == other.children
      end
      alias :== :eql?
    end

    And = Class.new(Nary)
    Or = Class.new(Nary)
  end
end
