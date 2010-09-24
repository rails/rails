module Arel
  module Visitors
    class Oracle < Arel::Visitors::ToSql
      private

      def visit_Arel_Nodes_SelectStatement o
        if o.limit && o.orders.empty? && !o.offset
          o.cores.last.wheres.push Nodes::LessThanOrEqual.new(
            Nodes::SqlLiteral.new('ROWNUM'), o.limit
          )
          o.limit = nil
          return super
        end

        if o.limit && o.offset
          limit = o.limit.to_i
          offset = o.offset
          o.limit = nil
          o.offset = nil
          sql = super
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
          limit = o.limit
          o.limit = nil
          return "SELECT * FROM (#{super}) WHERE ROWNUM <= #{limit}"
        end

        super
      end

      def visit_Arel_Nodes_Offset o
        "raw_rnum_ > #{visit o.value}"
      end
    end
  end
end
