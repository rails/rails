# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class InsertStatement < Arel::Nodes::Node
      attr_accessor :relation, :columns, :values, :select, :returning

      def initialize(relation = nil)
        super()
        @relation  = relation
        @columns   = []
        @values    = nil
        @select    = nil
        @returning = []
      end

      def initialize_copy(other)
        super
        @columns = @columns.clone
        @values =  @values.clone if @values
        @select =  @select.clone if @select
        @returning = @returning.clone if @returning
      end

      def hash
        [@relation, @columns, @values, @select, @returning].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.columns == other.columns &&
          self.select == other.select &&
          self.values == other.values &&
          self.returning == other.returning
      end
      alias :== :eql?
    end
  end
end
