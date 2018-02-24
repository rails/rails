# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Descending < Ordering
      def reverse
        Ascending.new(expr)
      end

      def direction
        :desc
      end

      def ascending?
        false
      end

      def descending?
        true
      end
    end
  end
end
