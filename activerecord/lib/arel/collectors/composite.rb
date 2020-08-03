# frozen_string_literal: true

module Arel # :nodoc: all
  module Collectors
    class Composite
      attr_accessor :preparable

      def initialize(left, right)
        @left = left
        @right = right
      end

      def <<(str)
        left << str
        right << str
        self
      end

      def add_bind(bind, &block)
        left.add_bind bind, &block
        right.add_bind bind, &block
        self
      end

      def add_binds(binds, &block)
        left.add_binds(binds, &block)
        right.add_binds(binds, &block)
        self
      end

      def value
        [left.value, right.value]
      end

      private
        attr_reader :left, :right
    end
  end
end
