module Arel
  module Nodes
    class StringJoin < Arel::Nodes::Join
      undef :constraint

      def initialize left, right
        super(left, right, nil)
      end
    end
  end
end
