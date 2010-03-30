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
      def operator; '!' end
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
    
    class GroupedPredicate < Polyadic
      def eval(row)
        group = additional_operands.inject([]) do |results, operand|
          results << operator.new(operand1, operand)
        end
        group.send(compounder) do |operation|
          operation.eval(row)
        end
      end
    end
    
    class Any < GroupedPredicate
      def compounder; :any? end
    end
    
    class All < GroupedPredicate
      def compounder; :all? end
    end

    class Equality < Binary
      def operator; :== end
    end

    class Inequality < Equality
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
