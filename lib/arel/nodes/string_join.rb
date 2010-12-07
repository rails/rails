module Arel
  module Nodes
    class StringJoin < Arel::Nodes::Join
      undef :constraint

      def initialize left, right, on = nil
        super
      end
    end
  end
end
