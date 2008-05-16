module Arel
  module Recursion
    module BaseCase
      # XXX
      def table
        self
      end

      def table_sql(formatter = Sql::TableReference.new(self))
        formatter.table self
      end
      
      def relation_for(attribute)
        self[attribute] && self
      end
    end
  end
end