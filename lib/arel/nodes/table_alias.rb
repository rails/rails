module Arel
  module Nodes
    class TableAlias < Arel::Nodes::Binary
      alias :name :right
      alias :relation :left
      alias :table_alias :name

      def [] name
        Attribute.new(self, name)
      end

      def table_name
        relation.respond_to?(:name) ? relation.name : name
      end

      def engine
        relation.engine
      end
    end
  end
end
