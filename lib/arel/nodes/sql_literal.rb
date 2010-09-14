module Arel
  module Nodes
    class SqlLiteral < String
      def count distinct = false
        Count.new [self], distinct
      end

      def sum
        Nodes::Sum.new [self], Nodes::SqlLiteral.new('sum_id')
      end

      def maximum
        Nodes::Max.new [self], Nodes::SqlLiteral.new('max_id')
      end
    end
  end
end
