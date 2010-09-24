module Arel
  module Visitors
    class Oracle < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_SelectStatement o
        o = order_hacks(o)

        if o.limit && o.orders.empty? && !o.offset
          o.cores.last.wheres.push Nodes::LessThanOrEqual.new(
            Nodes::SqlLiteral.new('ROWNUM'), o.limit
          )
          o.limit = nil
          return super
        end

        if o.limit && o.offset
          o        = o.dup
          limit    = o.limit.to_i
          offset   = o.offset
          o.limit  = nil
          o.offset = nil
          sql = super(o)
          return <<-eosql
              SELECT * FROM (
                SELECT raw_sql_.*, rownum raw_rnum_
                FROM (#{sql}) raw_sql_
                WHERE rownum <= #{offset.value.to_i + limit}
              )
              WHERE #{visit offset}
          eosql
        end

        if o.limit && !o.orders.empty?
          o       = o.dup
          limit   = o.limit
          o.limit = nil
          return "SELECT * FROM (#{super(o)}) WHERE ROWNUM <= #{limit}"
        end

        super
      end

      def visit_Arel_Nodes_Offset o
        "raw_rnum_ > #{visit o.value}"
      end

      ###
      # Hacks for the order clauses specific to Oracle
      def order_hacks o
        return o if o.orders.empty?
        return o unless o.cores.any? do |core|
          core.projections.any? do |projection|
            /DISTINCT.*FIRST_VALUE/ === projection
          end
        end
        orders   = o.orders
        o.orders = []
        orders.each_with_index do |order, i|
          o.orders <<
            Nodes::SqlLiteral.new("alias_#{i}__ #{'DESC' if /\bdesc$/i === order}")
        end
        o
      end
    end
  end
end
