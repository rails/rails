module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_Matches o, collector
        op = o.case_sensitive ? ' LIKE ' : ' ILIKE '
        collector = infix_value o, collector, op
        if o.escape
          collector << ' ESCAPE '
          visit o.escape, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_DoesNotMatch o, collector
        op = o.case_sensitive ? ' NOT LIKE ' : ' NOT ILIKE '
        collector = infix_value o, collector, op
        if o.escape
          collector << ' ESCAPE '
          visit o.escape, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_Regexp o, collector
        op = o.case_sensitive ? ' ~ ' : ' ~* '
        infix_value o, collector, op
      end

      def visit_Arel_Nodes_NotRegexp o, collector
        op = o.case_sensitive ? ' !~ ' : ' !~* '
        infix_value o, collector, op
      end

      def visit_Arel_Nodes_DistinctOn o, collector
        collector << "DISTINCT ON ( "
        visit(o.expr, collector) << " )"
      end

      def visit_Arel_Nodes_BindParam o, collector
        collector.add_bind(o) { |i| "$#{i}" }
      end
    end
  end
end
