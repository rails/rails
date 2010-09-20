module Arel
  module Nodes
    class In < Equality
      def initialize left, right
        raise if Arel::SelectManager === right
        super
      end
    end
  end
end
