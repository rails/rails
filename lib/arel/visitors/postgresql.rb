module Arel
  module Visitors
    class PostgreSQL < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_SelectStatement o
        if !o.orders.empty? && using_distinct_on?(o)
          subquery        = o.dup
          subquery.orders = []
          subquery.limit  = nil
          subquery.offset = nil

          sql = super(subquery)
          [
            "SELECT * FROM (#{sql}) AS id_list",
            "ORDER BY #{o.orders.map { |x| visit x }.join(', ')}",
            ("LIMIT #{o.limit}" if o.limit),
            (visit(o.offset) if o.offset),
          ].compact.join ' '
        else
          super
        end
      end

      def using_distinct_on?(o)
        o.cores.any? do |core|
          core.projections.any? do |projection|
            /DISTINCT ON/ === projection
          end
        end
      end
    end
  end
end
