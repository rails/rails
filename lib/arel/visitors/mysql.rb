module Arel
  module Visitors
    class MySQL < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_Union o, a, suppress_parens = false
        left_result = case o.left
                      when Arel::Nodes::Union
                        visit_Arel_Nodes_Union o.left, a, true
                      else
                        visit o.left, a
                      end

        right_result = case o.right
                       when Arel::Nodes::Union
                         visit_Arel_Nodes_Union o.right, a, true
                       else
                         visit o.right, a
                       end

        if suppress_parens
          "#{left_result} UNION #{right_result}"
        else
          "( #{left_result} UNION #{right_result} )"
        end
      end

      def visit_Arel_Nodes_Bin o, a
        "BINARY #{visit o.expr, a}"
      end

      ###
      # :'(
      # http://dev.mysql.com/doc/refman/5.0/en/select.html#id3482214
      def visit_Arel_Nodes_SelectStatement o, a
        o.limit = Arel::Nodes::Limit.new(18446744073709551615) if o.offset && !o.limit
        super
      end

      def visit_Arel_Nodes_SelectCore o, a
        o.froms ||= Arel.sql('DUAL')
        super
      end

      def visit_Arel_Nodes_UpdateStatement o, a
        [
          "UPDATE #{visit o.relation, a}",
          ("SET #{o.values.map { |value| visit value, a }.join ', '}" unless o.values.empty?),
          ("WHERE #{o.wheres.map { |x| visit x, a }.join ' AND '}" unless o.wheres.empty?),
          ("ORDER BY #{o.orders.map { |x| visit x, a }.join(', ')}" unless o.orders.empty?),
          (visit(o.limit, a) if o.limit),
        ].compact.join ' '
      end

    end
  end
end
