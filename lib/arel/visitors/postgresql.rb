module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_Lock o
        visit o.expr
      end

      def visit_Arel_Nodes_Matches o
        "#{visit o.left} ILIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_DoesNotMatch o
        "#{visit o.left} NOT ILIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_DistinctOn o
        "DISTINCT ON ( #{visit o.expr} )"
      end

      def aliased_orders orders
        #orders = o.orders.map { |x| visit x }.join(', ').split(',')
        list = []
        orders.each_with_index do |o,i|
          list <<
            [
              "id_list.alias_#{i}",
              (o.index(/desc/i) && 'DESC')
            ].compact.join(' ')
        end
        list
      end
    end
  end
end
