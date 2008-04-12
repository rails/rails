module ActiveRelation
  class Attribute
    attr_reader :relation, :name, :alias, :ancestor
    delegate :engine, :to => :relation

    def initialize(relation, name, options = {})
      @relation, @name, @alias, @ancestor = relation, name, options[:alias], options[:ancestor]
    end
    
    def alias_or_name
      @alias || name
    end

    module Transformations
      def as(aliaz = nil)
        Attribute.new(relation, name, :alias => aliaz, :ancestor => self)
      end
    
      def bind(new_relation)
        relation == new_relation ? self : Attribute.new(new_relation, name, :alias => @alias, :ancestor => self)
      end

      def to_attribute
        self
      end
    end
    include Transformations
    
    def qualified_name
      "#{prefix}.#{name}"
    end
    
    def column
      relation.column_for(self)
    end

    def ==(other)
      self.class  == other.class     and
      relation    == other.relation  and
      name        == other.name      and
      @alias      == other.alias     and
      ancestor    == other.ancestor
    end
    
    module Congruence
      def self.included(klass)
        klass.hash_on :name
      end
      
      def history
        [self] + (ancestor ? [ancestor, ancestor.history].flatten : [])
      end
      
      def =~(other)
        !(history & other.history).empty?
      end
    end
    include Congruence
    
    module Predications
      def eq(other)
        Equality.new(self, other)
      end

      def lt(other)
        LessThan.new(self, other)
      end

      def lteq(other)
        LessThanOrEqualTo.new(self, other)
      end

      def gt(other)
        GreaterThan.new(self, other)
      end

      def gteq(other)
        GreaterThanOrEqualTo.new(self, other)
      end

      def matches(regexp)
        Match.new(self, regexp)
      end
      
      def in(array)
        In.new(self, array)
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

    def to_sql(formatter = Sql::WhereCondition.new(engine))
      formatter.attribute prefix, name, self.alias
    end
    
    def format(object)
      object.to_sql(formatter)
    end
    
    private
    def formatter
      Sql::Attribute.new(self)
    end
    
    def prefix
      relation.prefix_for(self)
    end
  end
end