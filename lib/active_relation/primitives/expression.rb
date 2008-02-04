module ActiveRelation
  class Expression
    include Sql::Quoting
    
    attr_reader :attribute, :function_sql, :alias, :ancestor
    delegate :relation, :to => :attribute
    
    def initialize(attribute, function_sql, aliaz = nil, ancestor = nil)
      @attribute, @function_sql, @alias, @ancestor = attribute, function_sql, aliaz, ancestor
    end

    module Transformations
      def substitute(new_relation)
        Expression.new(attribute.substitute(new_relation), function_sql, @alias, self)
      end
    
      def as(aliaz)
        # key line -- note self
        Expression.new(attribute, function_sql, aliaz, self)
      end
      
      def to_attribute
        # key line -- note self
        Attribute.new(relation, @alias, nil, self)
      end
    end
    include Transformations
    
    def to_sql(strategy = nil)
      "#{function_sql}(#{attribute.to_sql})" + (@alias ? " AS #{quote_column_name(@alias)}" : '')
    end
    
    def ==(other)
      self.class == other.class and attribute == other.attribute and function_sql == other.function_sql and ancestor == other.ancestor and @alias == other.alias
    end
    alias_method :eql?, :==

    def hash
      attribute.hash + function_sql.hash
    end
    
    def =~(other)
      !(history & other.history).empty?
    end

    def history
      [self] + (ancestor ? [ancestor, ancestor.history].flatten : [])
    end
  end
end