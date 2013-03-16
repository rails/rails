module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_Matches o, a
        "#{visit o.left, a} ILIKE #{visit o.right, a}"
      end

      def visit_Arel_Nodes_DoesNotMatch o, a
        "#{visit o.left, a} NOT ILIKE #{visit o.right, a}"
      end

      def visit_Arel_Nodes_DistinctOn o, a
        "DISTINCT ON ( #{visit o.expr, a} )"
      end
    end
  end
end
