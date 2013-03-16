module Arel
  module Visitors
    class IBM_DB < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_Limit o, a
        "FETCH FIRST #{visit o.expr, a} ROWS ONLY"
      end

    end
  end
end
