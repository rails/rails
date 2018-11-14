# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class IBM_DB < Arel::Visitors::ToSql
      private

        def visit_Arel_Nodes_Limit(o, collector)
          collector << "FETCH FIRST "
          collector = visit o.expr, collector
          collector << " ROWS ONLY"
        end

        def null_safe_compare(o, collector)
          collector << "DECODE("
          collector = visit [o.left, o.right, 1, 0], collector
          collector << ")"
        end
    end
  end
end
