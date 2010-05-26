module Arel
  module Predicates
    class Binary < Predicate
      def eval(row)
        operand1.eval(row).send(operator, operand2.eval(row))
      end
    end

    class Unary < Predicate
      def eval(row)
        operand.eval(row).send(operator)
      end
    end

    class Not < Unary
      def eval(row)
        !operand.eval(row)
      end
    end

    class Polyadic < Predicate
      def eval(row)
        predicates.send(compounder) do |operation|
          operation.eval(row)
        end
      end
    end

    class Any < Polyadic
      def compounder; :any? end
    end

    class All < Polyadic
      def compounder; :all? end
    end

    class CompoundPredicate < Binary
      def eval(row)
        eval "operand1.eval(row) #{operator} operand2.eval(row)"
      end
    end

    class Or < CompoundPredicate
      def operator; :or end
    end

    class And < CompoundPredicate
      def operator; :and end
    end

    class Equality < Binary
      def operator; :== end
    end

    class Inequality < Binary
      def eval(row)
        operand1.eval(row) != operand2.eval(row)
      end
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

    class NotMatch < Binary
      def eval(row)
        operand1.eval(row) !~ operand2.eval(row)
      end
    end

    class In < Binary
      def eval(row)
        operand2.eval(row).include?(operand1.eval(row))
      end
    end

    class NotIn < Binary
      def eval(row)
        !(operand2.eval(row).include?(operand1.eval(row)))
      end
    end
  end
end
