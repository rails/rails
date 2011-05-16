module Arel
  module Visitors
    class Informix < Arel::Visitors::ToSql
      @skip = nil
        @first = nil 
      private
      def visit_Arel_Nodes_SelectStatement o
#        @skip = o.offset if o.offset 
#        @first = o.limit if o.limit
        [
          "SELECT",
          (visit(o.offset) if o.offset),
          (visit(o.limit) if o.limit),
          o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join,
          ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
          (visit(o.lock) if o.lock),
        ].compact.join ' '
      end
      def visit_Arel_Nodes_SelectCore o
        # s,f = @skip,@first
        # @skip, @first = nil,nil
        [
          "#{o.projections.map { |x| visit x }.join ', '}",
          ("FROM #{visit o.froms}" if o.froms),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND ' }" unless o.wheres.empty?),
          ("GROUP BY #{o.groups.map { |x| visit x }.join ', ' }" unless o.groups.empty?),
          (visit(o.having) if o.having),
        ].compact.join ' '
      end
      #(visit(o.offset) if o.offset) 
      def visit_Arel_Nodes_Offset o
        "SKIP #{visit o.expr}"
      end
      def visit_Arel_Nodes_Limit o
        "LIMIT #{visit o.expr}"
      end
    end
  end
end  

