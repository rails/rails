require 'set'

module Arel
  class Attribute
    attributes :relation, :name, :alias, :ancestor
    deriving :==
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

    def inspect
      "<Attribute #{name}>"
    end

    module Transformations
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

      def to_attribute(relation)
        bind(relation)
      end
    end
    include Transformations

    module Congruence
      def history
        @history ||= [self] + (ancestor ? ancestor.history : [])
      end

      def join?
        relation.join?
      end

      def root
        history.last
      end

      def original_relation
        @original_relation ||= original_attribute.relation
      end

      def original_attribute
        @original_attribute ||= history.detect { |a| !a.join? }
      end

      def find_correlate_in(relation)
        relation[self] || self
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
        Predicates::Equality.new(self, other)
      end

      def lt(other)
        Predicates::LessThan.new(self, other)
      end

      def lteq(other)
        Predicates::LessThanOrEqualTo.new(self, other)
      end

      def gt(other)
        Predicates::GreaterThan.new(self, other)
      end

      def gteq(other)
        Predicates::GreaterThanOrEqualTo.new(self, other)
      end

      def matches(regexp)
        Predicates::Match.new(self, regexp)
      end

      def in(array)
        Predicates::In.new(self, array)
      end
    end
    include Predications

    module Expressions
      def count(distinct = false)
        distinct ?  Distinct.new(self).count :  Count.new(self)
      end

      def sum
        Sum.new(self)
      end

      def maximum
        Maximum.new(self)
      end

      def minimum
        Minimum.new(self)
      end

      def average
        Average.new(self)
      end
    end
    include Expressions

    module Orderings
      def asc
        Ascending.new(self)
      end

      def desc
        Descending.new(self)
      end

      alias_method :to_ordering, :asc
    end
    include Orderings
  end
end
