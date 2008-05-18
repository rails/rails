module Arel
  class Expression < Attribute
    attr_reader :attribute, :function_sql
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
    
    def ==(other)
      Expression    == other.class          and
      attribute     == other.attribute      and
      function_sql  == other.function_sql   and
      ancestor      == other.ancestor       and
      @alias        == other.alias
    end
    
    module Transformations
      def as(aliaz)
        Expression.new(attribute, function_sql, aliaz, self)
      end
      
      # FIXME
      def bind(new_relation)
        # new_relation == relation ? self : Expression.new(attribute.bind(new_relation), function_sql, @alias, self)
        self
      end
          
      def to_attribute
        Attribute.new(relation, @alias, :ancestor => self)
      end
    end
    include Transformations
  end
end