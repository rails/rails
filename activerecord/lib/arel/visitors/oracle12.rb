# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class Oracle12 < Arel::Visitors::ToSql
      private

        def visit_Arel_Nodes_SelectStatement(o, collector)
          # Oracle does not allow LIMIT clause with select for update
          if o.limit && o.lock
            raise ArgumentError, <<-MSG
            'Combination of limit and lock is not supported.
            because generated SQL statements
            `SELECT FOR UPDATE and FETCH FIRST n ROWS` generates ORA-02014.`
          MSG
          end
          super
        end

        def visit_Arel_Nodes_SelectOptions(o, collector)
          collector = maybe_visit o.offset, collector
          collector = maybe_visit o.limit, collector
          maybe_visit o.lock, collector
        end

        def visit_Arel_Nodes_Limit(o, collector)
          collector << "FETCH FIRST "
          collector = visit o.expr, collector
          collector << " ROWS ONLY"
        end

        def visit_Arel_Nodes_Offset(o, collector)
          collector << "OFFSET "
          visit o.expr, collector
          collector << " ROWS"
        end

        def visit_Arel_Nodes_Except(o, collector)
          collector << "( "
          collector = infix_value o, collector, " MINUS "
          collector << " )"
        end

        def visit_Arel_Nodes_In(o, collector)
          if Array === o.right && !o.right.empty?
            o.right.delete_if { |value| unboundable?(value) }
          end

          if Array === o.right && o.right.empty?
            collector << "1=0"
          else
            first = true
            o.right.each_slice(in_clause_length) do |sliced_o_right|
              collector << " OR " unless first
              first = false

              collector = visit o.left, collector
              collector << " IN ("
              visit(sliced_o_right, collector)
              collector << ")"
            end
          end
          collector
        end

        def visit_Arel_Nodes_NotIn(o, collector)
          if Array === o.right && !o.right.empty?
            o.right.delete_if { |value| unboundable?(value) }
          end

          if Array === o.right && o.right.empty?
            collector << "1=1"
          else
            first = true
            o.right.each_slice(in_clause_length) do |sliced_o_right|
              collector << " AND " unless first
              first = false

              collector = visit o.left, collector
              collector << " NOT IN ("
              visit(sliced_o_right, collector)
              collector << ")"
            end
          end
          collector
        end

        def visit_Arel_Nodes_UpdateStatement(o, collector)
          # Oracle does not allow ORDER BY/LIMIT in UPDATEs.
          if o.orders.any? && o.limit.nil?
            # However, there is no harm in silently eating the ORDER BY clause if no LIMIT has been provided,
            # otherwise let the user deal with the error
            o = o.dup
            o.orders = []
          end

          super
        end

        def visit_Arel_Nodes_BindParam(o, collector)
          collector.add_bind(o.value) { |i| ":a#{i}" }
        end

        def is_distinct_from(o, collector)
          collector << "DECODE("
          collector = visit [o.left, o.right, 0, 1], collector
          collector << ")"
        end

        def in_clause_length
          1000
        end
    end
  end
end
