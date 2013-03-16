module Arel
  module Visitors
    class OrderClauses < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_SelectStatement o, a
        o.orders.map { |x| visit x, a }
      end
    end
  end
end
