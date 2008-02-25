module ActiveRelation
  module Sql
    module Quoting
      def connection
        Session.instance.connection
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
      
      def select(select_sql, aliaz)
        "(#{select_sql})" + (aliaz ? " AS #{quote_column_name(aliaz)}" : "")
      end
    end
    
    class Predicate < Strategy
      def attribute(relation_name, attribute_name, aliaz)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute_name)}"
      end
      
      def scalar(scalar, column = nil)
        quote(scalar, column)
      end
      
      def select(select_sql, aliaz)
        "(#{select_sql})"
      end
    end
    
    class Selection < Strategy
      def scalar(scalar)
        scalar
      end
    end
    
    class Relation < Strategy
      def select(select_sql, aliaz)
        select_sql
      end
    end
    
    class Aggregation < Strategy
      def select(select_sql, aliaz)
        "(#{select_sql}) AS #{quote_table_name(aliaz)}"
      end
    end
    
    class Attribute < Predicate
      def initialize(attribute)
        @attribute = attribute
      end
      
      def scalar(scalar)
        quote(scalar, @attribute.column)
      end
    end
    
    class Scalar < Predicate
    end
  end
end