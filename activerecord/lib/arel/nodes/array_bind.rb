# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    # Marker wrapping an array of values passed to a query method (created via
    # Arel.array_bind). ActiveRecord::PredicateBuilder turns it into a
    # HomogeneousArrayBind node for single array-bind delivery.
    class ArrayBind < Node
      attr_reader :values

      def initialize(values)
        @values = values.to_a
      end

      def hash
        [self.class, @values].hash
      end

      def eql?(other)
        self.class == other.class && @values == other.values
      end
      alias :== :eql?
    end
  end
end
