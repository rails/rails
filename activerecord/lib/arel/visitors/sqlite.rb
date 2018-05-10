# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class SQLite < Arel::Visitors::ToSql
      private

        # Locks are not supported in SQLite
        def visit_Arel_Nodes_Lock(_o, collector)
          collector
        end

        def visit_Arel_Nodes_SelectStatement(o, collector)
          o.limit = Arel::Nodes::Limit.new(-1) if o.offset && !o.limit
          super
        end

        def visit_Arel_Nodes_True(_o, collector)
          collector << "1"
        end

        def visit_Arel_Nodes_False(_o, collector)
          collector << "0"
        end
    end
  end
end
