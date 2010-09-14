module Arel
  module Nodes
    class Exists
      attr_reader :select_stmt

      def initialize select_stmt
        @select_stmt = select_stmt
      end
    end
  end
end
