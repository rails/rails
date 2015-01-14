module Arel
  module Visitors
    class WhereSql < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_SelectCore o, collector
        collector << "WHERE "
        wheres = o.wheres.map do |where|
          Nodes::SqlLiteral.new(@connection.visitor.accept(where, collector.class.new).value)
        end

        inject_join wheres, collector, ' AND '
      end
    end
  end
end
