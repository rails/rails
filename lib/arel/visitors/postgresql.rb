module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_Matches o, collector
        infix_value o, collector, ' ILIKE '
      end

      def visit_Arel_Nodes_DoesNotMatch o, collector
        infix_value o, collector, ' NOT ILIKE '
      end

      def visit_Arel_Nodes_Regexp o, collector
        infix_value o, collector, ' ~ '
      end

      def visit_Arel_Nodes_NotRegexp o, collector
        infix_value o, collector, ' !~ '
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
