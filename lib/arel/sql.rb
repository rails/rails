module Arel
  module Sql
    module Quoting
      delegate :quote_table_name, :quote_column_name, :quote, :to => :engine
    end
    
    class Formatter
      attr_reader :engine, :christener
      
      include Quoting
      
      def initialize(environment)
        @christener, @engine = environment.christener, environment.engine
      end
    end
    
    class SelectClause < Formatter
      def attribute(attribute)
        relation_name = @christener.name_for(attribute.original_relation)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute.name)}" + (attribute.alias ? " AS #{quote(attribute.alias.to_s)}" : "")
      end
      
      def select(select_sql, name)
        "(#{select_sql}) AS #{quote_table_name(name.to_s)}"
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
      def attribute(attribute)
        relation_name = @christener.name_for(attribute.original_relation)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute.name)}"
      end
    end
    
    class WhereCondition < Formatter
      def attribute(attribute)
        relation_name = @christener.name_for(attribute.original_relation)
        "#{quote_table_name(relation_name)}.#{quote_column_name(attribute.name)}"
      end
      
      def value(value)
        value.to_sql(self)
      end
      
      def scalar(value, column = nil)
        quote(value, column)
      end
      
      def select(select_sql, name)
        "(#{select_sql})"
      end
    end
    
    class SelectStatement < Formatter
      def select(select_sql, name)
        select_sql
      end
    end
    
    class TableReference < Formatter
      def select(select_sql, name)
        "(#{select_sql}) AS #{quote_table_name(name)}"
      end
      
      def table(table)
        aliaz = christener.name_for(table)
        quote_table_name(table.name) + (table.name != aliaz ? " AS " + engine.quote_table_name(aliaz) : '')
      end
    end
    
    class Attribute < WhereCondition
      def initialize(attribute)
        @attribute, @christener, @engine = attribute, attribute.christener, attribute.engine
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