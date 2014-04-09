module Arel
  module Visitors
    class MSSQL < Arel::Visitors::ToSql
      RowNumber = Struct.new :children

      private

      # `top` wouldn't really work here. I.e. User.select("distinct first_name").limit(10) would generate
      # "select top 10 distinct first_name from users", which is invalid query! it should be
      # "select distinct top 10 first_name from users"
      def visit_Arel_Nodes_Top o
        ""
      end

      def visit_Arel_Visitors_MSSQL_RowNumber o, collector
        collector << "ROW_NUMBER() OVER (ORDER BY "
        inject_join(o.children, collector, ', ') << ") as _row_num"
      end

      def visit_Arel_Nodes_SelectStatement o, collector
        if !o.limit && !o.offset
          return super
        end

        is_select_count = false
        o.cores.each { |x|
          core_order_by = row_num_literal determine_order_by(o.orders, x)
          if select_count? x
            x.projections = [core_order_by]
            is_select_count = true
          else
            x.projections << core_order_by
          end
        }

        if is_select_count
          # fixme count distinct wouldn't work with limit or offset
          collector << "SELECT COUNT(1) as count_id FROM ("
        end

        collector << "SELECT _t.* FROM ("
        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore x, c
        }
        collector << ") as _t WHERE #{get_offset_limit_clause(o)}"

        if is_select_count
          collector << ") AS subquery"
        else
          collector
        end
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

      def determine_order_by orders, x
        if orders.any?
          orders
        elsif x.groups.any?
          x.groups
        else
          pk = find_left_table_pk(x.froms)
          pk ? [pk] : []
        end
      end

      def row_num_literal order_by
        RowNumber.new order_by
      end

      def select_count? x
        x.projections.length == 1 && Arel::Nodes::Count === x.projections.first
      end

      # FIXME raise exception of there is no pk?
      # FIXME!! Table.primary_key will be deprecated. What is the replacement??
      def find_left_table_pk o
        return o.primary_key if o.instance_of? Arel::Table
        find_left_table_pk o.left if o.kind_of? Arel::Nodes::Join
      end
    end
  end
end
