# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Fragments < Arel::Nodes::Node
      attr_reader :values

      def initialize(values = [])
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

      def +(other)
        raise ArgumentError, "Expected Arel node" unless Arel.arel_node?(other)

        self.class.new([*@values, other])
      end

      def eql?(other)
        self.class == other.class &&
          self.values == other.values
      end
      alias :== :eql?
    end
  end
end
