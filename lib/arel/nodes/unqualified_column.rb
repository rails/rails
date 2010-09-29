module Arel
  module Nodes
    class UnqualifiedColumn
      attr_accessor :attribute

      def initialize attribute
        @attribute = attribute
      end

      def column
        @attribute.column
      end

      def name
        @attribute.name
      end
    end
  end
end
