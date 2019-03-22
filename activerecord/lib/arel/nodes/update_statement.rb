# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class UpdateStatement < Arel::Nodes::Node
      attr_accessor :relation, :wheres, :values, :orders, :limit, :offset, :key, :comment

      def initialize
        @relation = nil
        @wheres   = []
        @values   = []
        @orders   = []
        @limit    = nil
        @offset   = nil
        @key      = nil
        @comment  = nil
      end

      def initialize_copy(other)
        super
        @wheres = @wheres.clone
        @values = @values.clone
        @comment = @comment.clone if @comment
      end

      def hash
        [@relation, @wheres, @values, @orders, @limit, @offset, @key, @comment].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.wheres == other.wheres &&
          self.values == other.values &&
          self.orders == other.orders &&
          self.limit == other.limit &&
          self.offset == other.offset &&
          self.key == other.key &&
          self.comment == other.comment
      end
      alias :== :eql?
    end
  end
end
