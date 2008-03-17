module ActiveRelation
  module Sql
    module Quoting
      delegate :quote_table_name, :quote_column_name, :quote, :to => :engine
    end
    
    class Formatter
      attr_reader :engine
      
      include Quoting
      
      def initialize(engine)
        @engine = engine
      end
    end
    
    class SelectClause < Formatter
      def attribute(relation_name, attribute_name, aliaz)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute_name)}" + (aliaz ? " AS #{quote(aliaz.to_s)}" : "")
      end
      
      def select(select_sql, aliaz)
        "(#{select_sql})" + (aliaz ? " AS #{quote(aliaz)}" : "")
      end
      
      def value(value)
        value
      end
    end
    
    class PassThrough < Formatter
      def value(value)
        value
      end
    end
    
    class WhereClause < PassThrough
    end
    
    class OrderClause < PassThrough
      def attribute(relation_name, attribute_name, aliaz)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute_name)}"
      end
    end
    
    class WhereCondition < Formatter
      def attribute(relation_name, attribute_name, aliaz)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute_name)}"
      end
      
      def value(value)
        value.to_sql(self)
      end
      
      def scalar(value, column = nil)
        quote(value, column)
      end
      
      def select(select_sql, aliaz)
        "(#{select_sql})"
      end
    end
    
    class SelectStatement < Formatter
      def select(select_sql, aliaz)
        select_sql
      end
    end
    
    class TableReference < Formatter
      def select(select_sql, aliaz)
        "(#{select_sql}) AS #{quote_table_name(aliaz)}"
      end
    end
    
    class Attribute < WhereCondition
      def initialize(attribute)
        @attribute, @engine = attribute, attribute.engine
      end
      
      def scalar(scalar)
        quote(scalar, @attribute.column)
      end
      
      def array(array)
        "(" + array.collect { |e| e.to_sql(self) }.join(', ') + ")"
      end
      
      def range(left, right)
        "#{left} AND #{right}"
      end
    end
    
    class Value < WhereCondition
    end
  end
end