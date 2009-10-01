module Arel
  module Predicates
    class Predicate
      def or(other_predicate)
        Or.new(self, other_predicate)
      end

      def and(other_predicate)
        And.new(self, other_predicate)
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

    class GreaterThanOrEqualTo  < Binary; end
    class GreaterThan           < Binary; end
    class LessThanOrEqualTo     < Binary; end
    class LessThan              < Binary; end
    class Match                 < Binary; end
    class In                    < Binary; end
  end
end
