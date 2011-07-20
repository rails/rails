module Arel
  module Visitors
    class MySQL < Arel::Visitors::ToSql
      private
      def visit_Arel_Nodes_Union o, suppress_parens = false
        left_result = case o.left
                      when Arel::Nodes::Union
                        visit_Arel_Nodes_Union o.left, true
                      else
                        visit o.left
                      end

        right_result = case o.right
                       when Arel::Nodes::Union
                         visit_Arel_Nodes_Union o.right, true
                       else
                         visit o.right
                       end

        if suppress_parens
          "#{left_result} UNION #{right_result}"
        else
          "( #{left_result} UNION #{right_result} )"
        end
      end

      def visit_Arel_Nodes_Bin o
        "BINARY #{visit o.expr}"
      end

      def visit_Arel_Nodes_Lock o
        visit o.expr
      end

      ###
      # :'(
      # http://dev.mysql.com/doc/refman/5.0/en/select.html#id3482214
      def visit_Arel_Nodes_SelectStatement o
        o.limit = Arel::Nodes::Limit.new(18446744073709551615) if o.offset && !o.limit
        super
      end

      def visit_Arel_Nodes_SelectCore o
        o.froms ||= Arel.sql('DUAL')
        super
      end

      def visit_Arel_Nodes_UpdateStatement o
        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |value| visit value }.join ', '}" unless o.values.empty?),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND '}" unless o.wheres.empty?),
          ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
          (visit(o.limit) if o.limit),
        ].compact.join ' '
      end

    end
  end
end
