# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class SQLite < Arel::Visitors::ToSql
      private
        def visit_Arel_Nodes_UpdateStatement(o, collector)
          collector.retryable = false
          o = prepare_update_statement(o)

          collector << "UPDATE "

          # UPDATE with JOIN is in the form of:
          #
          #   UPDATE t1
          #   SET ..
          #   FROM t2
          #   WHERE t1.join_id = t2.join_id
          #
          # Or if more than one join is present:
          #
          #   UPDATE t1
          #   SET ..
          #   FROM t2
          #   JOIN t3 ON t2.join_id = t3.join_id
          #   WHERE t1.join_id = t2.join_id
          if has_join_sources?(o)
            visit o.relation.left, collector
            collect_nodes_for o.values, collector, " SET "

            collector << " FROM "
            first_join, *remaining_joins = o.relation.right
            visit first_join.left, collector

            if remaining_joins && !remaining_joins.empty?
              collector << " "
              remaining_joins.each do |join|
                visit join, collector
                collector << " "
              end
            end

            collect_nodes_for [first_join.right.expr] + o.wheres, collector, " WHERE ", " AND "
          else
            collector = visit o.relation, collector
            collect_nodes_for o.values, collector, " SET "
            collect_nodes_for o.wheres, collector, " WHERE ", " AND "
          end

          collect_nodes_for o.orders, collector, " ORDER BY "
          maybe_visit o.limit, collector
        end

        def prepare_update_statement(o)
          # Sqlite need to be built with the SQLITE_ENABLE_UPDATE_DELETE_LIMIT compile-time option
          # to support LIMIT/OFFSET/ORDER in UPDATE and DELETE statements.
          if has_join_sources?(o) && !has_limit_or_offset_or_orders?(o) && !has_group_by_and_having?(o) &&
            # The SQLite3 dialect isn't flexible enough to allow anything other than a inner join
            # for the first join:
            #   UPDATE table SET .. FROM joined_table WHERE ...
            (o.relation.right.first.is_a?(Arel::Nodes::InnerJoin))
            o
          else
            super
          end
        end

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
