# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class In < Equality
      def invert
        Arel::Nodes::NotIn.new(left, right)
      end
    end
  end
end
