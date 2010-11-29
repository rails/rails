module Arel
  module Nodes
    class Unary < Arel::Nodes::Node
      attr_accessor :expr

      def initialize expr
        @expr = expr
      end
    end
  end
end
