module ActiveRelation
  module Primitives
    class Attribute
      include SqlBuilder
  
      attr_reader :relation, :name, :alias
  
      def initialize(relation, name, aliaz = nil)
        @relation, @name, @alias = relation, name, aliaz
      end
  
      def alias(aliaz = nil)
        aliaz ? Attribute.new(relation, name, aliaz) : @alias
      end
  
      def qualified_name
        "#{relation.table}.#{name}"
      end
  
      def qualify
        self.alias(qualified_name)
      end
  
      def ==(other)
        relation == other.relation and name == other.name and @alias == other.alias
      end

      module Predications
        include Predicates
        
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
  
      def to_sql(options = {})
        "#{quote_table_name(relation.table)}.#{quote_column_name(name)}" + (options[:use_alias] && self.alias ? " AS #{self.alias.to_s.to_sql}" : "")
      end
    end
  end
end