# frozen_string_literal: true

module Arel
  module Nodes
    class DeleteStatement < Arel::Nodes::Node
      attr_accessor :left, :right
      attr_accessor :limit

      alias :relation :left
      alias :relation= :left=
      alias :wheres :right
      alias :wheres= :right=

      def initialize(relation = nil, wheres = [])
        super()
        @left = relation
        @right = wheres
      end

      def initialize_copy(other)
        super
        @left  = @left.clone if @left
        @right = @right.clone if @right
      end

      def hash
        [self.class, @left, @right].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.left == other.left &&
          self.right == other.right
      end
      alias :== :eql?
    end
  end
end
