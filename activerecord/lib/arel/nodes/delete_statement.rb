# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class DeleteStatement < Arel::Nodes::Node
      attr_accessor :left, :right, :orders, :limit, :lock, :offset, :key

      alias :relation :left
      alias :relation= :left=
      alias :wheres :right
      alias :wheres= :right=

      def initialize(relation = nil, wheres = [])
        super()
        @left = relation
        @right = wheres
        @orders = []
        @limit = nil
        @lock = nil
        @offset = nil
        @key = nil
      end

      def initialize_copy(other)
        super
        @left  = @left.clone if @left
        @right = @right.clone if @right
      end

      def hash
        [self.class, @left, @right, @orders, @limit, @lock, @offset, @key].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.left == other.left &&
          self.right == other.right &&
          self.orders == other.orders &&
          self.limit == other.limit &&
          self.lock == other.lock &&
          self.offset == other.offset &&
          self.key == other.key
      end
      alias :== :eql?
    end
  end
end
