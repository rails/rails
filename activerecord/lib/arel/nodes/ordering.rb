# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Ordering < Unary
      def nulls_first
        NullsFirst.new(self)
      end

      def nulls_last
        NullsLast.new(self)
      end
    end

    class NullsFirst < Ordering; end
    class NullsLast < Ordering; end
  end
end
