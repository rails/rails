module Arel
  module Sql
    class Christener
      def initialize
        @names = {}
      end

      def name_for(relation)
        table = relation.table
        name = table.table_alias || table.name
        list = @names[name] ||= []

        list << table unless list.include? table

        idx = list.index table
        name + (idx == 0 ? '' : "_#{idx + 1}")
      end
    end
  end
end
