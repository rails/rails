module ActiveRelation
  class Aggregation
    include Sql::Quoting
    
    attr_reader :attribute, :function_sql, :alias
    delegate :relation, :to => :attribute
    
    def initialize(attribute, function_sql, aliaz = nil)
      @attribute, @function_sql, @alias = attribute, function_sql, aliaz
    end

    module Transformations
      def substitute(new_relation)
        Aggregation.new(attribute.substitute(new_relation), function_sql, @alias)
      end
    
      def as(aliaz)
        Aggregation.new(attribute, function_sql, aliaz)
      end
      
      def to_attribute
        Attribute.new(relation, @alias)
      end
    end
    include Transformations
    
    def to_sql(strategy = nil)
      "#{function_sql}(#{attribute.to_sql})" + (@alias ? " AS #{quote_column_name(@alias)}" : '')
    end
    
    def ==(other)
      self.class == other.class and attribute == other.attribute and function_sql == other.function_sql
    end
  end
end