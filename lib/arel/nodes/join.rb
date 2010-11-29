module Arel
  module Nodes
    class Join < Arel::Nodes::Node
      attr_accessor :left, :right, :constraint

      def initialize left, right, constraint
        @left       = left
        @right      = right
        @constraint = constraint
      end
    end
  end
end
