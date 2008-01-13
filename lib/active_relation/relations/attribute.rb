module ActiveRelation
  module Primitives
    class Attribute
      include ::ActiveRelation::SqlBuilder
  
      attr_reader :relation, :name, :alias
  
      def initialize(relation, name, aliaz = nil)
        @relation, @name, @alias = relation, name, aliaz
      end
  
      def alias(aliaz = nil)
        aliaz ? ActiveRelation::Primitives::Attribute.new(relation, name, aliaz) : @alias
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
        def equals(other)
          Predicates::Equality.new(self, other)
        end
  
        def less_than(other)
          Predicates::LessThan.new(self, other)
        end
  
        def less_than_or_equal_to(other)
          Predicates::LessThanOrEqualTo.new(self, other)
        end
  
        def greater_than(other)
          Predicates::GreaterThan.new(self, other)
        end
  
        def greater_than_or_equal_to(other)
          Predicates::GreaterThanOrEqualTo.new(self, other)
        end
  
        def matches(regexp)
          Predicates::Match.new(self, regexp)
        end
      end
      include Predications
  
      def to_sql(options = {})
        "#{quote_table_name(relation.table)}.#{quote_column_name(name)}" + (options[:use_alias] && self.alias ? " AS #{self.alias.to_s.to_sql}" : "")
      end
    end
  end
end