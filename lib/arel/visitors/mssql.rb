module Arel
  module Visitors
    class MSSQL < Arel::Visitors::ToSql
      private

      def build_subselect key, o
        stmt     = super
        core     = stmt.cores.first
        core.top = Nodes::Top.new(o.limit.expr) if o.limit
        stmt
      end

      def visit_Arel_Nodes_Limit o
        ""
      end

      def visit_Arel_Nodes_Top o
        "TOP #{visit o.expr}"
      end

    end
  end
end
