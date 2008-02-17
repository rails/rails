module ActiveRelation
  class Expression < Attribute
    include Sql::Quoting
    
    attr_reader :attribute, :function_sql
    delegate :relation, :to => :attribute
    alias_method :name, :alias
    
    def initialize(attribute, function_sql, aliaz = nil, ancestor = nil)
      @attribute, @function_sql, @alias, @ancestor = attribute, function_sql, aliaz, ancestor
    end

    module Transformations
      def as(aliaz)
        Expression.new(attribute, function_sql, aliaz, self)
      end
      
      def bind(new_relation)
        new_relation == relation ? self : Expression.new(attribute.bind(new_relation), function_sql, @alias, self)
      end
          
      def to_attribute
        Attribute.new(relation, @alias, nil, self)
      end
    end
    include Transformations
    
    def to_sql(strategy = nil)
      "#{function_sql}(#{attribute.to_sql})" + (@alias ? " AS #{quote_column_name(@alias)}" : '')
    end
    
    def ==(other)
      self.class    == other.class          and
      attribute     == other.attribute      and
      function_sql  == other.function_sql   and
      ancestor      == other.ancestor       and
      @alias        == other.alias
    end
  end
end