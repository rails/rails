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
          #   UPDATE t1 AS __active_record_update_alias
          #   SET ..
          #   FROM t1 JOIN t2 ON t2.join_id = t1.join_id ..
          #   WHERE t1.id = __active_record_update_alias.id AND ..
          if has_join_sources?(o)
            collector = visit o.relation.left, collector
            collect_nodes_for o.values, collector, " SET "
            collector << " FROM "
            collector = inject_join o.relation.right, collector, " "
          else
            collector = visit o.relation, collector
            collect_nodes_for o.values, collector, " SET "
          end

          collect_nodes_for o.wheres, collector, " WHERE ", " AND "
          collect_nodes_for o.orders, collector, " ORDER BY "
          maybe_visit o.limit, collector
          maybe_visit o.comment, collector
        end

        def prepare_update_statement(o)
          # Sqlite need to be built with the SQLITE_ENABLE_UPDATE_DELETE_LIMIT compile-time option
          # to support LIMIT/OFFSET/ORDER in UPDATE and DELETE statements.
          if o.key && has_join_sources?(o) && !has_group_by_and_having?(o) && !has_limit_or_offset_or_orders?(o)
            # Join clauses cannot reference the target table, so alias the
            # updated table, place the entire relation in the FROM clause, and
            # add a self-join (which requires the primary key)
            stmt = o.clone
            stmt.relation, stmt.wheres = o.relation.clone, o.wheres.clone
            stmt.relation.right = [stmt.relation.left, *stmt.relation.right]
            stmt.relation.left = stmt.relation.left.alias("__active_record_update_alias")
            Array.wrap(o.key).each do |key|
              stmt.wheres << key.eq(stmt.relation.left[key.name])
            end
            stmt
          else
            super
          end
        end

        def visit_Arel_Nodes_TableAlias(o, collector)
          # "AS" is not optional in "{UPDATE | DELETE} table AS alias ..."
          collector = visit o.relation, collector
          collector << " AS "
          collector << quote_table_name(o.name)
        end

        # Locks are not supported in SQLite
        def visit_Arel_Nodes_Lock(o, collector)
          collector
        end

        def visit_Arel_Nodes_SelectStatement(o, collector)
          o.limit = Arel::Nodes::Limit.new(-1) if o.offset && !o.limit
          super
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
