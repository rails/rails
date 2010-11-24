module Arel
  module Nodes
    class Not < Arel::Nodes::Node
      attr_reader :expr

      def initialize expr
        @expr = expr
      end
    end
  end
end
