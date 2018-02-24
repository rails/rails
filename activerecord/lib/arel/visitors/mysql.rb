# frozen_string_literal: true

module Arel
  module Visitors
    class MySQL < Arel::Visitors::ToSql
      private
        def visit_Arel_Nodes_Union(o, collector, suppress_parens = false)
          unless suppress_parens
            collector << "( "
          end

          collector =   case o.left
                        when Arel::Nodes::Union
                          visit_Arel_Nodes_Union o.left, collector, true
                        else
                          visit o.left, collector
          end

          collector << " UNION "

          collector =    case o.right
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

        def visit_Arel_Nodes_UpdateStatement(o, collector)
          collector << "UPDATE "
          collector = visit o.relation, collector

          unless o.values.empty?
            collector << " SET "
            collector = inject_join o.values, collector, ", "
          end

          unless o.wheres.empty?
            collector << " WHERE "
            collector = inject_join o.wheres, collector, " AND "
          end

          unless o.orders.empty?
            collector << " ORDER BY "
            collector = inject_join o.orders, collector, ", "
          end

          maybe_visit o.limit, collector
        end

        def visit_Arel_Nodes_Concat(o, collector)
          collector << " CONCAT("
          visit o.left, collector
          collector << ", "
          visit o.right, collector
          collector << ") "
          collector
        end
    end
  end
end
