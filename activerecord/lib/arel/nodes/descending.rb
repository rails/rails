# frozen_string_literal: true

# :markup: markdown
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
