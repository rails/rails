module ActiveRelation
  module Sql
    module Quoting
      def connection
        ActiveRecord::Base.connection
      end
  
      delegate :quote_table_name, :quote_column_name, :quote, :to => :connection
    end
    
    class Strategy
      include Quoting
    end
    
    class Projection < Strategy
      def attribute(relation_name, attribute_name, aliaz)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute_name)}" + (aliaz ? " AS #{quote(aliaz.to_s)}" : "")
      end
      
      def select(select_sql)
        "(#{select_sql})"
      end
    end
    
    class Predicate < Strategy
      def attribute(relation_name, attribute_name, aliaz)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute_name)}"
      end
      
      def scalar(scalar)
        scalar
      end
      
      def select(select_sql)
        "(#{select_sql})"
      end
    end
    
    class Select < Strategy
      def select(select_sql)
        select_sql
      end
    end
    
    class Scalar < Strategy
      def scalar(scalar)
        quote(scalar)
      end
    end
  end
end