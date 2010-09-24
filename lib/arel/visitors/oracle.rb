module Arel
  module Visitors
    class Oracle < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement o
        if o.limit && o.orders.empty?
          o.cores.last.wheres.push Nodes::LessThanOrEqual.new(
            Nodes::SqlLiteral.new('ROWNUM'), o.limit
          )
          o.limit = nil
          return super
        end

        if o.limit && !o.orders.empty?
          limit = o.limit
          o.limit = nil
          return "SELECT * FROM (#{super}) WHERE ROWNUM <= #{limit}"
        end

        super
      end
    end
  end
end
