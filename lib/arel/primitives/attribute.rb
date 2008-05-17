require 'set'

module Arel
  class Attribute
    attr_reader :relation, :name, :alias, :ancestor
    delegate :engine, :christener, :to => :relation

    def initialize(relation, name, options = {})
      @relation, @name, @alias, @ancestor = relation, name, options[:alias], options[:ancestor]
    end
    
    def named?(hypothetical_name)
      (@alias || name).to_s == hypothetical_name.to_s
    end
    
    def aggregation?
      false
    end

    def column
      original_relation.column_for(self)
    end
        
    def format(object)
      object.to_sql(Sql::Attribute.new(self))
    end

    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.attribute self
    end
    
    def ==(other)
      self.class  == other.class     and
      name        == other.name      and
      @alias      == other.alias     and
      relation    == other.relation  and
      ancestor    == other.ancestor
    end

    def original_relation
      @original_relation ||= relation.relation_for(self)
    end
    
    def original_attribute
      @original_attribute ||= original_relation[self]
    end

    module Transformations
      delegate :size, :to => :history
      
      def self.included(klass)
        klass.send :alias_method, :eql?, :==
      end
      
      def hash
        @hash ||= history.size + name.hash + relation.hash
      end
      
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
    
    module Congruence
      def history
        @history ||= [self] + (ancestor ? ancestor.history : [])
      end
      
      def match?(other)
        !(history & other.history).empty?
      end
      
      def descends_from?(other)
        history.include?(other)
      end
      
      def /(other)
        other ? (history & other.history).size : 0
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
  end
end