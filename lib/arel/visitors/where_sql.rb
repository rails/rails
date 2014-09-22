module Arel
  module Visitors
    class WhereSql < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_SelectCore o, collector
        collector << "WHERE "
        inject_join o.wheres, collector, ' AND '
      end
    end
  end
end
