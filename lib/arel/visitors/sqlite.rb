module Arel
  module Visitors
    class SQLite < Arel::Visitors::ToSql
      private

      # Locks are not supported in SQLite
      def visit_Arel_Nodes_Lock o, a
      end

      def visit_Arel_Nodes_SelectStatement o, a
        o.limit = Arel::Nodes::Limit.new(-1) if o.offset && !o.limit
        super
      end
    end
  end
end
