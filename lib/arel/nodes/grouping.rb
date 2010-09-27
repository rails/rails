module Arel
  module Nodes
    class Grouping < Arel::Nodes::Node
      attr_accessor :expr

      def initialize expression
        @expr = expression
      end
    end
  end
end
