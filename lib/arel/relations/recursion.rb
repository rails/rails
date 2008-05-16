module Arel
  module Recursion
    module BaseCase
      def table
        self
      end

      def table_sql(formatter = Sql::TableReference.new(self))
        formatter.table self
      end
      
      def relation_for(attribute)
        self[attribute] && self
      end
      
      def join?
        false
      end
      
      def aggregation?
        false
      end
    end
  end
end