# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
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

        # In the simple case, PostgreSQL allows us to place FROM or JOINs directly into the UPDATE
        # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
        # these, we must use a subquery.
        def prepare_update_statement(o)
          if has_join_sources?(o) && !has_limit_or_offset_or_orders?(o) && !has_group_by_and_having?(o)
            o
          else
            super
          end
        end

        def visit_Arel_Nodes_Matches(o, collector)
          op = o.case_sensitive ? " LIKE " : " ILIKE "
          collector = infix_value o, collector, op
          if o.escape
            collector << " ESCAPE "
            visit o.escape, collector
          else
            collector
          end
        end

        def visit_Arel_Nodes_DoesNotMatch(o, collector)
          op = o.case_sensitive ? " NOT LIKE " : " NOT ILIKE "
          collector = infix_value o, collector, op
          if o.escape
            collector << " ESCAPE "
            visit o.escape, collector
          else
            collector
          end
        end

        def visit_Arel_Nodes_Regexp(o, collector)
          op = o.case_sensitive ? " ~ " : " ~* "
          infix_value o, collector, op
        end

        def visit_Arel_Nodes_NotRegexp(o, collector)
          op = o.case_sensitive ? " !~ " : " !~* "
          infix_value o, collector, op
        end

        def visit_Arel_Nodes_DistinctOn(o, collector)
          collector << "DISTINCT ON ( "
          visit(o.expr, collector) << " )"
        end

        def visit_Arel_Nodes_GroupingElement(o, collector)
          collector << "( "
          visit(o.expr, collector) << " )"
        end

        def visit_Arel_Nodes_Cube(o, collector)
          collector << "CUBE"
          grouping_array_or_grouping_element o, collector
        end

        def visit_Arel_Nodes_RollUp(o, collector)
          collector << "ROLLUP"
          grouping_array_or_grouping_element o, collector
        end

        def visit_Arel_Nodes_GroupingSet(o, collector)
          collector << "GROUPING SETS"
          grouping_array_or_grouping_element o, collector
        end

        def visit_Arel_Nodes_Lateral(o, collector)
          collector << "LATERAL "
          grouping_parentheses o.expr, collector
        end

        def visit_Arel_Nodes_IsNotDistinctFrom(o, collector)
          collector = visit o.left, collector
          collector << " IS NOT DISTINCT FROM "
          visit o.right, collector
        end

        def visit_Arel_Nodes_IsDistinctFrom(o, collector)
          collector = visit o.left, collector
          collector << " IS DISTINCT FROM "
          visit o.right, collector
        end

        BIND_BLOCK = proc { |i| "$#{i}" }
        private_constant :BIND_BLOCK

        def bind_block; BIND_BLOCK; end

        # Utilized by GroupingSet, Cube & RollUp visitors to
        # handle grouping aggregation semantics
        def grouping_array_or_grouping_element(o, collector)
          if o.expr.is_a? Array
            collector << "( "
            visit o.expr, collector
            collector << " )"
          else
            visit o.expr, collector
          end
        end
    end
  end
end
