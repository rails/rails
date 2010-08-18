module Arel
  module Nodes
    class UnqualifiedColumn
      def initialize attribute
        @attribute = attribute
      end

      def name
        @attribute.name
      end
    end
  end
end
