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
        has_attribute?(attribute) && self
      end      
    end
  end
end