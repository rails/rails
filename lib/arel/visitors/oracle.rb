module Arel
  module Visitors
    class Oracle < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement o
        if o.limit
          o.cores.last.wheres.push Nodes::LessThanOrEqual.new(
            Nodes::SqlLiteral.new('ROWNUM'), o.limit
          )
          o.limit = nil
        end
        super
      end
    end
  end
end
