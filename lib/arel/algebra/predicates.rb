module Arel
  module Predicates
    class Predicate
      def or(other_predicate)
        Or.new(self, other_predicate)
      end

      def and(other_predicate)
        And.new(self, other_predicate)
      end
      
      def not
        Not.new(self)
      end
    end
    
    class Polyadic < Predicate
      attributes :operator, :operand1, :additional_operands
      
      def initialize(operator, operand1, *additional_operands)
        @operator = operator
        @operand1 = operand1
        @additional_operands = additional_operands.uniq
      end
      
      def ==(other)
        self.class === other          and
        @operator  ==  operator       and
        @operand1  ==  other.operand1 and
        same_elements?(@additional_operands, other.additional_operands)
      end
      
      def bind(relation)
        self.class.new(
          operator,
          operand1.find_correlate_in(relation),
          *additional_operands.map {|o| o.find_correlate_in(relation)}
        )
      end
      
      private
      
      def same_elements?(a1, a2)
        [:select, :inject, :size].each do |m|
          return false unless [a1, a2].each {|a| a.respond_to?(m) }
        end
        a1.inject({}) { |h,e| h[e] = a1.select { |i| i == e }.size; h } ==
        a2.inject({}) { |h,e| h[e] = a2.select { |i| i == e }.size; h }
      end
    end
    
    class Unary < Predicate
      attributes :operand
      deriving :initialize, :==
      
      def bind(relation)
        self.class.new(operand.find_correlate_in(relation))
      end
    end

    class Binary < Predicate
      attributes :operand1, :operand2
      deriving :initialize

      def ==(other)
        self.class === other          and
        @operand1  ==  other.operand1 and
        @operand2  ==  other.operand2
      end

      def bind(relation)
        self.class.new(operand1.find_correlate_in(relation), operand2.find_correlate_in(relation))
      end
    end

    class Equality < Binary
      def ==(other)
        Equality === other and
          ((operand1 == other.operand1 and operand2 == other.operand2) or
           (operand1 == other.operand2 and operand2 == other.operand1))
      end
    end

    class Inequality            < Equality; end
    class GreaterThanOrEqualTo  < Binary;   end
    class GreaterThan           < Binary;   end
    class LessThanOrEqualTo     < Binary;   end
    class LessThan              < Binary;   end
    class Match                 < Binary;   end
    class NotMatch              < Binary;   end
    class In                    < Binary;   end
    class NotIn                 < Binary;   end
  end
end
