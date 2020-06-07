# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Comment < Arel::Nodes::Node
      attr_reader :values

      def initialize(values)
        super()
        @values = values
      end

      def initialize_copy(other)
        super
        @values = @values.clone
      end

      def hash
        [@values].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.values == other.values
      end
      alias :== :eql?
    end
  end
end
