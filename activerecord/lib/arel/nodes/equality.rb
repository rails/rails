# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class Equality < Arel::Nodes::Binary
      include FetchAttribute

      def equality?; true; end

      def invert
        Arel::Nodes::NotEqual.new(left, right)
      end
    end

    class CaseSensitiveEquality < Arel::Nodes::Binary
      include FetchAttribute

      def equality?; true; end
    end

    class CaseInsensitiveEquality < Arel::Nodes::Binary
      include FetchAttribute

      def equality?; true; end
    end
  end
end
