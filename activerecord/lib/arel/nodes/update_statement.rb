# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UpdateStatement < Arel::Nodes::Node
      attr_accessor :relation, :from, :wheres, :values, :groups, :havings, :orders, :limit, :offset, :key

      def initialize(relation = nil)
        super()
        @relation = relation
        @from     = nil
        @wheres   = []
        @values   = []
        @groups   = []
        @havings  = []
        @orders   = []
        @limit    = nil
        @offset   = nil
        @key      = nil
      end

      def initialize_copy(other)
        super
        @wheres = @wheres.clone
        @values = @values.clone
      end

      def hash
        [@relation, @from, @wheres, @values, @orders, @limit, @offset, @key].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.from == other.from &&
          self.wheres == other.wheres &&
          self.values == other.values &&
          self.groups == other.groups &&
          self.havings == other.havings &&
          self.orders == other.orders &&
          self.limit == other.limit &&
          self.offset == other.offset &&
          self.key == other.key
      end
      alias :== :eql?
    end
  end
end
