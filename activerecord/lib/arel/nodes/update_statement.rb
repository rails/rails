# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UpdateStatement < Arel::Nodes::Node
      attr_accessor :relation, :wheres, :values, :groups, :havings, :orders, :from, :limit, :offset, :key

      def initialize(relation = nil)
        super()
        @relation = relation
        @wheres   = []
        @values   = []
        @groups   = []
        @havings  = []
        @orders   = []
        @from     = nil
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
        [@relation, @wheres, @values, @orders, @from, @limit, @offset, @key].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.wheres == other.wheres &&
          self.values == other.values &&
          self.groups == other.groups &&
          self.havings == other.havings &&
          self.orders == other.orders &&
          self.from == other.from &&
          self.limit == other.limit &&
          self.offset == other.offset &&
          self.key == other.key
      end
      alias :== :eql?
    end
  end
end
