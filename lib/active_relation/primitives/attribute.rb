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
    end
    include Transformations
    
    def qualified_name
      "#{relation.name}.#{name}"
    end

    def ==(other)
      relation == other.relation and name == other.name and @alias == other.alias
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
    
    module Aggregations
      def count
        Aggregation.new(self, "COUNT")
      end
      
      def sum
        Aggregation.new(self, "SUM")
      end
      
      def maximum
        Aggregation.new(self, "MAX")
      end
      
      def minimum
        Aggregation.new(self, "MIN")
      end
      
      def average
        Aggregation.new(self, "AVG")
      end
    end
    include Aggregations

    def to_sql(strategy = Sql::Predicate.new)
      strategy.attribute relation.name, name, self.alias
    end
  end
end