# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class BindParam < Node
      attr_reader :value

      def initialize(value)
        @value = value
        super()
      end

      def hash
        [self.class, self.value].hash
      end

      def eql?(other)
        other.is_a?(BindParam) &&
          value == other.value
      end
      alias :== :eql?

      def nil?
        value.nil?
      end

      def infinite?
        value.respond_to?(:infinite?) && value.infinite?
      end

      def unboundable?
        value.respond_to?(:unboundable?) && value.unboundable?
      end
    end
  end
end
