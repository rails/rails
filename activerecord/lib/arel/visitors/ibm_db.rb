# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class IBM_DB < Arel::Visitors::ToSql
      private
        def visit_Arel_Nodes_SelectCore(o, collector)
          collector = super
          maybe_visit o.optimizer_hints, collector
        end

        def visit_Arel_Nodes_OptimizerHints(o, collector)
          hints = o.expr.map { |v| sanitize_as_sql_comment(v) }.join
          collector << "/* <OPTGUIDELINES>#{hints}</OPTGUIDELINES> */"
        end

        def visit_Arel_Nodes_Limit(o, collector)
          collector << "FETCH FIRST "
          collector = visit o.expr, collector
          collector << " ROWS ONLY"
        end

        def is_distinct_from(o, collector)
          collector << "DECODE("
          collector = visit [o.left, o.right, 0, 1], collector
          collector << ")"
        end

        def collect_optimizer_hints(o, collector)
          collector
        end
    end
  end
end
