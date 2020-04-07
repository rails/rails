# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UpdateStatement < Arel::Nodes::Node
      attr_accessor :relation, :wheres, :values, :orders, :limit, :lock, :offset, :key

      def initialize
        @relation = nil
        @wheres   = []
        @values   = []
        @orders   = []
        @limit    = nil
        @lock     = nil
        @offset   = nil
        @key      = nil
      end

      def initialize_copy(other)
        super
        @wheres = @wheres.clone
        @values = @values.clone
      end

      def hash
        [@relation, @wheres, @values, @orders, @limit, @lock, @offset, @key].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.wheres == other.wheres &&
          self.values == other.values &&
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
