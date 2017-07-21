# frozen_string_literal: true
module Arel
  module Nodes
    class BindParam < Node
      attr_reader :value

      def initialize(value)
        @value = value
        super()
      end

      def ==(other)
        other.is_a?(BindParam) &&
          value == other.value
      end
    end
  end
end
