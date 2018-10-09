# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class MySQL < Arel::Visitors::ToSql
      private
        def visit_Arel_Nodes_Union(o, collector, suppress_parens = false)
          unless suppress_parens
            collector << "( "
          end

          case o.left
          when Arel::Nodes::Union
            visit_Arel_Nodes_Union o.left, collector, true
          else
            visit o.left, collector
          end

          collector << " UNION "

          case o.right
          when Arel::Nodes::Union
            visit_Arel_Nodes_Union o.right, collector, true
          else
            visit o.right, collector
          end

          if suppress_parens
            collector
          else
            collector << " )"
          end
        end

        def visit_Arel_Nodes_Bin(o, collector)
          collector << "BINARY "
          visit o.expr, collector
        end

        def visit_Arel_Nodes_UnqualifiedColumn(o, collector)
          visit o.expr, collector
        end

        ###
        # :'(
        # http://dev.mysql.com/doc/refman/5.0/en/select.html#id3482214
        def visit_Arel_Nodes_SelectStatement(o, collector)
          if o.offset && !o.limit
            o.limit = Arel::Nodes::Limit.new(18446744073709551615)
          end
          super
        end

        def visit_Arel_Nodes_SelectCore(o, collector)
          o.froms ||= Arel.sql("DUAL")
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

        # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
        # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
        # these, we must use a subquery.
        def prepare_update_statement(o)
          if o.offset || has_join_sources?(o) && has_limit_or_offset_or_orders?(o)
            super
          else
            o
          end
        end
        alias :prepare_delete_statement :prepare_update_statement

        # MySQL is too stupid to create a temporary table for use subquery, so we have
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
            core.projections = [Arel.sql(quote_column_name(key.name))]
          end
        end
    end
  end
end
