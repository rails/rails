# frozen_string_literal: true
module Arel
  module Nodes
    class BindParam < Node
      attr_accessor :value

      def initialize(value)
        @value = value
        super()
      end

      def ==(other)
        other.is_a?(BindParam) &&
          value == other.value
      end

      def nil?
        value.nil?
      end
    end
  end
end
