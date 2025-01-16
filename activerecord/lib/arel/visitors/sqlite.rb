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

        # Queries used in UNION should not be wrapped by parentheses,
        # because it is an invalid syntax in SQLite.
        def infix_value_with_paren(o, collector, value, suppress_parens = false)
          collector << "( " unless suppress_parens

          left = o.left.is_a?(Nodes::Grouping) ? o.left.expr : o.left
          collector = if left.class == o.class
            infix_value_with_paren(left, collector, value, true)
          else
            grouping_parentheses left, collector, false
          end

          collector << value

          right = o.right.is_a?(Nodes::Grouping) ? o.right.expr : o.right
          collector = if right.class == o.class
            infix_value_with_paren(right, collector, value, true)
          else
            grouping_parentheses right, collector, false
          end

          collector << " )" unless suppress_parens
          collector
        end
    end
  end
end
