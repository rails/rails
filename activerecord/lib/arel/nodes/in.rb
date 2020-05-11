# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class In < Arel::Nodes::Binary
      include FetchAttribute

      def invert
        Arel::Nodes::NotIn.new(left, right)
      end
    end
  end
end
