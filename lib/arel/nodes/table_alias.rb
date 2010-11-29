module Arel
  module Nodes
    class TableAlias < Arel::Nodes::Binary
      alias :name :left
      alias :relation :right
      alias :table_alias :name

      def [] name
        Attribute.new self, name
      end
    end
  end
end
