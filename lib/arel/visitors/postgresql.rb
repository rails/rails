module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_Lock o
        visit o.expr
      end

      def visit_Arel_Nodes_SelectStatement o
        if !o.orders.empty? && using_distinct_on?(o)
          subquery        = o.dup
          subquery.orders = []
          subquery.limit  = nil
          subquery.offset = nil

          sql = super(subquery)
          [
            "SELECT * FROM (#{sql}) AS id_list",
            "ORDER BY #{aliased_orders(o.orders).join(', ')}",
            (visit(o.limit) if o.limit),
            (visit(o.offset) if o.offset),
          ].compact.join ' '
        else
          super
        end
      end

      def visit_Arel_Nodes_Matches o
        "#{visit o.left} ILIKE #{visit o.right}"
      end

      def visit_Arel_Nodes_DoesNotMatch o
        "#{visit o.left} NOT ILIKE #{visit o.right}"
      end

      def using_distinct_on?(o)
        o.cores.any? do |core|
          core.projections.any? do |projection|
            /DISTINCT ON/ === projection
          end
        end
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
