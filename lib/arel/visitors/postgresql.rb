# frozen_string_literal: true
module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      CUBE = 'CUBE'
      ROLLUP = 'ROLLUP'
      GROUPING_SET = 'GROUPING SET'

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

      def visit_Arel_Nodes_GroupingElement o, collector
        collector << "( "
        visit(o.expr, collector) << " )"
      end

      def visit_Arel_Nodes_Cube o, collector
        collector << CUBE
        grouping_array_or_grouping_element o, collector
      end

      def visit_Arel_Nodes_RollUp o, collector
        collector << ROLLUP
        grouping_array_or_grouping_element o, collector
      end

      def visit_Arel_Nodes_GroupingSet o, collector
        collector << GROUPING_SET
        grouping_array_or_grouping_element o, collector
      end

      # Utilized by GroupingSet, Cube & RollUp visitors to
      # handle grouping aggregation semantics
      def grouping_array_or_grouping_element o, collector
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
