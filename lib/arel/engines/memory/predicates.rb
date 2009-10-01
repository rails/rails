module Arel
  module Predicates
    class Binary < Predicate
      def eval(row)
        operand1.eval(row).send(operator, operand2.eval(row))
      end
    end

    class Equality < Binary
      def operator; :== end
    end

    class GreaterThanOrEqualTo < Binary
      def operator; :>= end
    end

    class GreaterThan < Binary
      def operator; :> end
    end

    class LessThanOrEqualTo < Binary
      def operator; :<= end
    end

    class LessThan < Binary
      def operator; :< end
    end

    class Match < Binary
      def operator; :=~ end
    end

    class In < Binary
      def operator; :include? end
    end
  end
end
