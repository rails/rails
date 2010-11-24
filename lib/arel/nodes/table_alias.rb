module Arel
  module Nodes
    class TableAlias
      attr_reader :name, :relation
      alias :table_alias :name

      def initialize name, relation
        @name     = name
        @relation = relation
      end

      def [] name
        Attribute.new self, name
      end
    end
  end
end
