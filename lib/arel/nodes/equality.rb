module Arel
  module Nodes
    class Equality
      attr_accessor :left, :right

      def initialize left, right
        @left  = left
        @right = right
      end
    end
  end
end
