module Arel
  module Nodes
    class SqlLiteral < String
      def count distinct = false
        Count.new [self], distinct
      end
    end
  end
end
