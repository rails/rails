module Arel
  module Sql
    class Christener
      def initialize
        @names = {}
      end

      def name_for(relation)
        table = relation.table
        name = table.table_alias || table.name
        @names[name] ||= []

        @names[name] << table unless @names[name].include? table

        idx = @names[name].index table
        name + (idx == 0 ? '' : "_#{idx + 1}")
      end
    end
  end
end
