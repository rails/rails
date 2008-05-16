module Arel
  module Recursion
    module BaseCase
      def table
        self
      end

      def table_sql(formatter = Sql::TableReference.new(self))
        formatter.table self
      end
      
      def root?
        true
      end
      
      def relation_for(attribute)
        self[attribute] && self
      end
    end
  end
  
  class Relation
    def root?
      false
    end
  end
end