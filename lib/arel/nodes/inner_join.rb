module Arel
  module Nodes
    class InnerJoin < Arel::Nodes::Join
      def initialize left, right
        raise if right == Arel::Nodes::StringJoin
        super
      end
    end
  end
end
