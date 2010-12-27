module Arel
  module Visitors
    class MSSQL < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_Limit o
        ""
      end

      def visit_Arel_Nodes_Top o
        "TOP #{visit o.expr}"
      end

    end
  end
end
