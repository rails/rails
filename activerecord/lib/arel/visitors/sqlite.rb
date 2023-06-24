# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class SQLite < Arel::Visitors::ToSql
      private
        # Locks are not supported in SQLite
        def visit_Arel_Nodes_Lock(o, collector)
          collector
        end

        def visit_Arel_Nodes_SelectStatement(o, collector)
          o.limit = Arel::Nodes::Limit.new(-1) if o.offset && !o.limit
          super
        end

        def visit_Arel_Nodes_True(o, collector)
          collector << "1"
        end

        def visit_Arel_Nodes_False(o, collector)
          collector << "0"
        end

        def visit_Arel_Nodes_IsNotDistinctFrom(o, collector)
          collector = visit o.left, collector
          collector << " IS "
          visit o.right, collector
        end

        def visit_Arel_Nodes_IsDistinctFrom(o, collector)
          collector = visit o.left, collector
          collector << " IS NOT "
          visit o.right, collector
        end

        def visit_Arel_Nodes_Regexp(o, collector)
          infix_value o, collector, " REGEXP "
        end

        def visit_Arel_Nodes_NotRegexp(o, collector)
          infix_value o, collector, " NOT REGEXP "
        end
    end
  end
end
