module ActiveRelation
  class Attribute
    attr_reader :relation, :name, :alias

    def initialize(relation, name, aliaz = nil)
      @relation, @name, @alias = relation, name, aliaz
    end

    module Transformations
      def as(aliaz = nil)
        Attribute.new(relation, name, aliaz)
      end
    
      def substitute(new_relation)
        Attribute.new(new_relation, name, @alias)
      end

      def qualify
        self.as(qualified_name)
      end
      
      def to_attribute
        self
      end
    end
    include Transformations
    
    def qualified_name
      "#{relation.name}.#{name}"
    end

    def ==(other)
      self.class == other.class and relation == other.relation and name == other.name and @alias == other.alias
    end

    module Predications
      def equals(other)
        Equality.new(self, other)
      end

      def less_than(other)
        LessThan.new(self, other)
      end

      def less_than_or_equal_to(other)
        LessThanOrEqualTo.new(self, other)
      end

      def greater_than(other)
        GreaterThan.new(self, other)
      end

      def greater_than_or_equal_to(other)
        GreaterThanOrEqualTo.new(self, other)
      end

      def matches(regexp)
        Match.new(self, regexp)
      end
    end
    include Predications
    
    module Expressions
      def count
        Expression.new(self, "COUNT")
      end
      
      def sum
        Expression.new(self, "SUM")
      end
      
      def maximum
        Expression.new(self, "MAX")
      end
      
      def minimum
        Expression.new(self, "MIN")
      end
      
      def average
        Expression.new(self, "AVG")
      end
    end
    include Expressions

    def to_sql(strategy = Sql::Predicate.new)
      strategy.attribute relation.name, name, self.alias
    end
  end
end