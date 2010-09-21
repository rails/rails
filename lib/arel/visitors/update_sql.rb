module Arel
  module Visitors
    module UpdateSql
      def visit_Arel_Nodes_UpdateStatement o
        if o.orders.empty? && o.limit.nil?
          wheres = o.wheres
        else
          stmt             = Nodes::SelectStatement.new
          core             = stmt.cores.first
          core.froms       = o.relation
          core.projections = [o.relation.primary_key]
          stmt.limit       = o.limit
          stmt.orders      = o.orders

          wheres = [Nodes::In.new(o.relation.primary_key, [stmt])]
        end

        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |value| visit value }.join ', '}" unless o.values.empty?),
          ("WHERE #{wheres.map { |x| visit x }.join ' AND '}" unless wheres.empty?)
        ].compact.join ' '
      end
    end
  end
end
