# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class DeleteStatement < Arel::Nodes::Node
      attr_accessor :relation, :wheres, :groups, :havings, :orders, :limit, :offset, :with, :key

      def initialize(relation = nil, wheres = [])
        super()
        @relation = relation
        @wheres = wheres
        @groups = []
        @havings = []
        @orders = []
        @limit = nil
        @offset = nil
        @key = nil
        @with = nil
      end

      def initialize_copy(other)
        super
        @relation = @relation.clone if @relation
        @wheres = @wheres.clone if @wheres
      end

      def hash
        [self.class, @relation, @wheres, @orders, @limit, @offset, @with, @key].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.wheres == other.wheres &&
          self.orders == other.orders &&
          self.groups == other.groups &&
          self.havings == other.havings &&
          self.limit == other.limit &&
          self.offset == other.offset &&
          self.with == other.with &&
          self.key == other.key
      end
      alias :== :eql?
    end
  end
end
