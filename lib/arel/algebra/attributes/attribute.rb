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
      methods = {
        :eq => "Equality",
        :noteq => "Inequality",
        :lt => "LessThan",
        :lteq => "LessThanOrEqualTo",
        :gt => "GreaterThan",
        :gteq => "GreaterThanOrEqualTo",
        :matches => "Match",
        :notmatches => "NotMatch",
        :in => "In",
        :notin => "NotIn"
      }
      
      def self.predication(name, klass)
        methods = {
          :operator => "
            def #{name}(other)
              Predicates::#{klass}.new(self, other)
            end
          ",
          :any => "
            def #{name}_any(*others)
              Predicates::Any.new(Predicates::#{klass}, self, *others)
            end
          ",
          :all => "
            def #{name}_all(*others)
              Predicates::All.new(Predicates::#{klass}, self, *others)
            end
          "
        }
        [:operator, :any, :all].each do |method_name|
          module_eval methods[method_name], __FILE__, __LINE__
        end
      end
      
      methods.each_pair do |method_name, class_name|
        predication(method_name, class_name)
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
