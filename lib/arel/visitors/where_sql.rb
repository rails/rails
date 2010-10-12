module Arel
  module Visitors
    class WhereSql < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectCore o
        "WHERE #{o.wheres.map { |x| visit x }.join ' AND ' }"
      end
    end
  end
end
