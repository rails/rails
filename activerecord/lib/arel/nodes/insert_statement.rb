# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class InsertStatement < Arel::Nodes::Node
      attr_accessor :relation, :columns, :values, :select, :comment

      def initialize
        super()
        @relation = nil
        @columns  = []
        @values   = nil
        @select   = nil
        @comment  = nil
      end

      def initialize_copy(other)
        super
        @columns = @columns.clone
        @values =  @values.clone if @values
        @select =  @select.clone if @select
        @comment =  @comment.clone if @comment
      end

      def hash
        [@relation, @columns, @values, @select, @comment].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.columns == other.columns &&
          self.select == other.select &&
          self.values == other.values &&
          self.comment == other.comment
      end
      alias :== :eql?
    end
  end
end
