require 'set'

module Arel
  class TypecastError < StandardError ; end
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
        @hash ||= name.hash + root.relation.hash
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

      def eq_any(*others)
        Predicates::Any.build(Predicates::Equality, self, *others)
      end

      def eq_all(*others)
        Predicates::All.build(Predicates::Equality, self, *others)
      end

      def not_eq(other)
        Predicates::Inequality.new(self, other)
      end

      def not_eq_any(*others)
        Predicates::Any.build(Predicates::Inequality, self, *others)
      end

      def not_eq_all(*others)
        Predicates::All.build(Predicates::Inequality, self, *others)
      end

      def lt(other)
        Predicates::LessThan.new(self, other)
      end

      def lt_any(*others)
        Predicates::Any.build(Predicates::LessThan, self, *others)
      end

      def lt_all(*others)
        Predicates::All.build(Predicates::LessThan, self, *others)
      end

      def lteq(other)
        Predicates::LessThanOrEqualTo.new(self, other)
      end

      def lteq_any(*others)
        Predicates::Any.build(Predicates::LessThanOrEqualTo, self, *others)
      end

      def lteq_all(*others)
        Predicates::All.build(Predicates::LessThanOrEqualTo, self, *others)
      end

      def gt(other)
        Predicates::GreaterThan.new(self, other)
      end

      def gt_any(*others)
        Predicates::Any.build(Predicates::GreaterThan, self, *others)
      end

      def gt_all(*others)
        Predicates::All.build(Predicates::GreaterThan, self, *others)
      end

      def gteq(other)
        Predicates::GreaterThanOrEqualTo.new(self, other)
      end

      def gteq_any(*others)
        Predicates::Any.build(Predicates::GreaterThanOrEqualTo, self, *others)
      end

      def gteq_all(*others)
        Predicates::All.build(Predicates::GreaterThanOrEqualTo, self, *others)
      end

      def matches(other)
        Predicates::Match.new(self, other)
      end

      def matches_any(*others)
        Predicates::Any.build(Predicates::Match, self, *others)
      end

      def matches_all(*others)
        Predicates::All.build(Predicates::Match, self, *others)
      end

      def not_matches(other)
        Predicates::NotMatch.new(self, other)
      end

      def not_matches_any(*others)
        Predicates::Any.build(Predicates::NotMatch, self, *others)
      end

      def not_matches_all(*others)
        Predicates::All.build(Predicates::NotMatch, self, *others)
      end

      def in(other)
        Predicates::In.new(self, other)
      end

      def in_any(*others)
        Predicates::Any.build(Predicates::In, self, *others)
      end

      def in_all(*others)
        Predicates::All.build(Predicates::In, self, *others)
      end

      def not_in(other)
        Predicates::NotIn.new(self, other)
      end

      def not_in_any(*others)
        Predicates::Any.build(Predicates::NotIn, self, *others)
      end

      def not_in_all(*others)
        Predicates::All.build(Predicates::NotIn, self, *others)
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

    module Types
      def type_cast(value)
        if root == self
          raise NotImplementedError, "#type_cast should be implemented in a subclass."
        else
          root.type_cast(value)
        end
      end

      def type_cast_to_numeric(value, method)
        return unless value
        if value.respond_to?(:to_str)
          str = value.to_str.strip
          return if str.empty?
          return $1.send(method) if str =~ /\A(-?(?:0|[1-9]\d*)(?:\.\d+)?|(?:\.\d+))\z/
        elsif value.respond_to?(method)
          return value.send(method)
        end
        raise typecast_error(value)
      end

      def typecast_error(value)
        raise TypecastError, "could not typecast #{value.inspect} to #{self.class.name.split('::').last}"
      end
    end
    include Types
  end
end
