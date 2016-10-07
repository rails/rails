# frozen_string_literal: true
module Arel
  module Visitors
    class Informix < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_SelectStatement o, collector
        collector << "SELECT "
        collector = maybe_visit o.offset, collector
        collector = maybe_visit o.limit, collector
        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore x, c
        }
        if o.orders.any?
          collector << "ORDER BY "
          collector = inject_join o.orders, collector, ", "
        end
        collector = maybe_visit o.lock, collector
      end
      def visit_Arel_Nodes_SelectCore o, collector
        collector = inject_join o.projections, collector, ", "
        froms = false
        if o.source && !o.source.empty?
          froms = true
          collector << " FROM "
          collector = visit o.source, collector
        end

        if o.wheres.any?
          collector << " WHERE "
          collector = inject_join o.wheres, collector, " AND "
        end

        if o.groups.any?
          collector << "GROUP BY "
          collector = inject_join o.groups, collector, ", "
        end

        if o.havings.any?
          collector << " HAVING "
          collector = inject_join o.havings, collector, " AND "
        end
        collector
      end

      def visit_Arel_Nodes_Offset o, collector
        collector << "SKIP "
        visit o.expr, collector
      end
      def visit_Arel_Nodes_Limit o, collector
        collector << "FIRST "
        visit o.expr, collector
        collector << " "
      end
    end
  end
end

