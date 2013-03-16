module Arel
  module Visitors
    class MSSQL < Arel::Visitors::ToSql
      private

      # `top` wouldn't really work here. I.e. User.select("distinct first_name").limit(10) would generate
      # "select top 10 distinct first_name from users", which is invalid query! it should be
      # "select distinct top 10 first_name from users"
      def visit_Arel_Nodes_Top o, a
        ""
      end

      def visit_Arel_Nodes_SelectStatement o, a
        if !o.limit && !o.offset
          return super o, a
        end

        select_order_by = "ORDER BY #{o.orders.map { |x| visit x, a }.join(', ')}" unless o.orders.empty?

        is_select_count = false
        sql = o.cores.map { |x|
          core_order_by = select_order_by || determine_order_by(x, a)
          if select_count? x
            x.projections = [row_num_literal(core_order_by)]
            is_select_count = true
          else
            x.projections << row_num_literal(core_order_by)
          end

          visit_Arel_Nodes_SelectCore x, a
        }.join

        sql = "SELECT _t.* FROM (#{sql}) as _t WHERE #{get_offset_limit_clause(o)}"
        # fixme count distinct wouldn't work with limit or offset
        sql = "SELECT COUNT(1) as count_id FROM (#{sql}) AS subquery" if is_select_count
        sql
      end

      def get_offset_limit_clause o
        first_row = o.offset ? o.offset.expr.to_i + 1 : 1
        last_row  = o.limit ? o.limit.expr.to_i - 1 + first_row : nil
        if last_row
          " _row_num BETWEEN #{first_row} AND #{last_row}"
        else
          " _row_num >= #{first_row}"
        end
      end

      def determine_order_by x, a
        unless x.groups.empty?
          "ORDER BY #{x.groups.map { |g| visit g, a }.join ', ' }"
        else
          "ORDER BY #{find_left_table_pk(x.froms, a)}"
        end
      end

      def row_num_literal order_by
        Nodes::SqlLiteral.new("ROW_NUMBER() OVER (#{order_by}) as _row_num")
      end

      def select_count? x
        x.projections.length == 1 && Arel::Nodes::Count === x.projections.first
      end

      # fixme raise exception of there is no pk?
      # fixme!! Table.primary_key will be depricated. What is the replacement??
      def find_left_table_pk o, a
        return visit o.primary_key, a if o.instance_of? Arel::Table
        find_left_table_pk o.left, a if o.kind_of? Arel::Nodes::Join
      end
    end
  end
end
