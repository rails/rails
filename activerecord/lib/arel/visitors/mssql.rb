# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class MSSQL < Arel::Visitors::ToSql
      RowNumber = Struct.new :children

      def initialize(*)
        @primary_keys = {}
        super
      end

      private

        def visit_Arel_Nodes_IsNotDistinctFrom(o, collector)
          right = o.right

          if right.nil?
            collector = visit o.left, collector
            collector << " IS NULL"
          else
            collector << "EXISTS (VALUES ("
            collector = visit o.left, collector
            collector << ") INTERSECT VALUES ("
            collector = visit right, collector
            collector << "))"
          end
        end

        def visit_Arel_Nodes_IsDistinctFrom(o, collector)
          if o.right.nil?
            collector = visit o.left, collector
            collector << " IS NOT NULL"
          else
            collector << "NOT "
            visit_Arel_Nodes_IsNotDistinctFrom o, collector
          end
        end

        def visit_Arel_Visitors_MSSQL_RowNumber(o, collector)
          collector << "ROW_NUMBER() OVER (ORDER BY "
          inject_join(o.children, collector, ", ") << ") as _row_num"
        end

        def visit_Arel_Nodes_SelectStatement(o, collector)
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
          collector = o.cores.inject(collector) { |c, x|
            visit_Arel_Nodes_SelectCore x, c
          }
          collector << ") as _t WHERE #{get_offset_limit_clause(o)}"

          if is_select_count
            collector << ") AS subquery"
          else
            collector
          end
        end

        def visit_Arel_Nodes_SelectCore(o, collector)
          collector = super
          maybe_visit o.optimizer_hints, collector
        end

        def visit_Arel_Nodes_OptimizerHints(o, collector)
          hints = o.expr.map { |v| sanitize_as_sql_comment(v) }.join(", ")
          collector << "OPTION (#{hints})"
        end

        def get_offset_limit_clause(o)
          first_row = o.offset ? o.offset.expr.to_i + 1 : 1
          last_row  = o.limit ? o.limit.expr.to_i - 1 + first_row : nil
          if last_row
            " _row_num BETWEEN #{first_row} AND #{last_row}"
          else
            " _row_num >= #{first_row}"
          end
        end

        def visit_Arel_Nodes_DeleteStatement(o, collector)
          collector << "DELETE "
          if o.limit
            collector << "TOP ("
            visit o.limit.expr, collector
            collector << ") "
          end
          collector << "FROM "
          collector = visit o.relation, collector
          if o.wheres.any?
            collector << " WHERE "
            inject_join o.wheres, collector, " AND "
          else
            collector
          end
        end

        def collect_optimizer_hints(o, collector)
          collector
        end

        def determine_order_by(orders, x)
          if orders.any?
            orders
          elsif x.groups.any?
            x.groups
          else
            pk = find_left_table_pk(x.froms)
            pk ? [pk] : []
          end
        end

        def row_num_literal(order_by)
          RowNumber.new order_by
        end

        def select_count?(x)
          x.projections.length == 1 && Arel::Nodes::Count === x.projections.first
        end

        # FIXME raise exception of there is no pk?
        def find_left_table_pk(o)
          if o.kind_of?(Arel::Nodes::Join)
            find_left_table_pk(o.left)
          elsif o.instance_of?(Arel::Table)
            find_primary_key(o)
          end
        end

        def find_primary_key(o)
          @primary_keys[o.name] ||= begin
            primary_key_name = @connection.primary_key(o.name)
            # some tables might be without primary key
            primary_key_name && o[primary_key_name]
          end
        end
    end
  end
end
