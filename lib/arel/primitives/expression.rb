module Arel
  class Expression < Attribute
    attributes :attribute, :function_sql, :alias, :ancestor
    deriving :==
    delegate :relation, :to => :attribute
    alias_method :name, :alias
    
    def initialize(attribute, function_sql, aliaz = nil, ancestor = nil)
      @attribute, @function_sql, @alias, @ancestor = attribute, function_sql, aliaz, ancestor
    end
    
    def to_sql(formatter = Sql::SelectClause.new(relation))
      formatter.expression self
    end
    
    def aggregation?
      true
    end
    
    module Transformations
      def as(aliaz)
        Expression.new(attribute, function_sql, aliaz, self)
      end
      
      def bind(new_relation)
        new_relation == relation ? self : Expression.new(attribute.bind(new_relation), function_sql, @alias, self)
      end
          
      def to_attribute
        Attribute.new(relation, @alias, :ancestor => self)
      end
    end
    include Transformations
  end
end