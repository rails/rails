module Arel
  module Visitors
    class SQLite < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_SelectStatement o
        o.limit = Arel::Nodes::Limit.new(-1) if o.offset && !o.limit
        super
      end
    end
  end
end
