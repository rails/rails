module Arel
  module Nodes
    class TableAlias
      attr_reader :name, :relation, :columns
      alias :table_alias :name

      def initialize name, relation
        @name     = name
        @relation = relation
        @columns  = relation.columns.map { |column|
          column.dup.tap { |col| col.relation = self }
        }
      end

      def [] name
        name = name.to_sym
        columns.find { |column| column.name == name }
      end
    end
  end
end
