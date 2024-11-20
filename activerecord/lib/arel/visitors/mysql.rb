# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class MySQL < Arel::Visitors::ToSql
      private
        def visit_Arel_Nodes_Bin(o, collector)
          collector << "CAST("
          visit o.expr, collector
          collector << " AS BINARY)"
        end

        def visit_Arel_Nodes_UnqualifiedColumn(o, collector)
          visit o.expr, collector
        end

        ###
        # :'(
        # To retrieve all rows from a certain offset up to the end of the result set,
        # you can use some large number for the second parameter.
        # https://dev.mysql.com/doc/refman/en/select.html
        def visit_Arel_Nodes_SelectStatement(o, collector)
          if o.offset && !o.limit
            o.limit = Arel::Nodes::Limit.new(18446744073709551615)
          end
          super
        end

        def visit_Arel_Nodes_SelectCore(o, collector)
          o.froms ||= Arel.sql("DUAL", retryable: true)
          super
        end

        def visit_Arel_Nodes_Concat(o, collector)
          collector << " CONCAT("
          visit o.left, collector
          collector << ", "
          visit o.right, collector
          collector << ") "
          collector
        end

        def visit_Arel_Nodes_IsNotDistinctFrom(o, collector)
          collector = visit o.left, collector
          collector << " <=> "
          visit o.right, collector
        end

        def visit_Arel_Nodes_IsDistinctFrom(o, collector)
          collector << "NOT "
          visit_Arel_Nodes_IsNotDistinctFrom o, collector
        end

        def visit_Arel_Nodes_Regexp(o, collector)
          infix_value o, collector, " REGEXP "
        end

        def visit_Arel_Nodes_NotRegexp(o, collector)
          infix_value o, collector, " NOT REGEXP "
        end

        def visit_Arel_Nodes_NullsFirst(o, collector)
          visit(o.expr.expr, collector) << " IS NOT NULL, "
          visit(o.expr, collector)
        end

        def visit_Arel_Nodes_NullsLast(o, collector)
          visit(o.expr.expr, collector) << " IS NULL, "
          visit(o.expr, collector)
        end

        def visit_Arel_Nodes_Cte(o, collector)
          collector << quote_table_name(o.name)
          collector << " AS "
          visit o.relation, collector
        end

        # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
        # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
        # these, we must use a subquery.
        def prepare_update_statement(o)
          if o.offset || has_group_by_and_having?(o) ||
            has_join_sources?(o) && has_limit_or_offset_or_orders?(o)
            super
          else
            o
          end
        end
        alias :prepare_delete_statement :prepare_update_statement

        # MySQL doesn't automatically create a temporary table for use subquery, so we have
        # to give it some prompting in the form of a subsubquery.
        def build_subselect(key, o)
          subselect = super

          # Materialize subquery by adding distinct
          # to work with MySQL 5.7.6 which sets optimizer_switch='derived_merge=on'
          unless has_limit_or_offset_or_orders?(subselect)
            core = subselect.cores.last
            core.set_quantifier = Arel::Nodes::Distinct.new
          end

          Nodes::SelectStatement.new.tap do |stmt|
            core = stmt.cores.last
            core.froms = Nodes::Grouping.new(subselect).as("__active_record_temp")
            core.projections = [Arel.sql(quote_column_name(key.name), retryable: true)]
          end
        end
    end
  end
end
