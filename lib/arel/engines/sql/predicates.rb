module Arel
  module Predicates
    class Binary < Predicate
      def to_sql(formatter = nil)
        "#{operand1.to_sql} #{predicate_sql} #{operand1.format(operand2)}"
      end
    end

    class Unary < Predicate
      def to_sql(formatter = nil)
        "#{predicate_sql} (#{operand.to_sql(formatter)})"
      end
    end

    class Not < Unary
      def predicate_sql; "NOT" end
    end

    class CompoundPredicate < Binary
      def to_sql(formatter = nil)
        "(#{operand1.to_sql(formatter)} #{predicate_sql} #{operand2.to_sql(formatter)})"
      end
    end

    class Or < CompoundPredicate
      def predicate_sql; "OR" end
    end

    class And < CompoundPredicate
      def predicate_sql; "AND" end
    end

    class Polyadic < Predicate
      def to_sql(formatter = nil)
        "(" +
          predicates.map {|p| p.to_sql(formatter)}.join(" #{predicate_sql} ") +
        ")"
      end
    end

    class Any < Polyadic
      def predicate_sql; "OR" end
    end

    class All < Polyadic
      def predicate_sql; "AND" end
    end

    class Equality < Binary
      def predicate_sql
        operand2.equality_predicate_sql
      end
    end

    class Inequality < Binary
      def predicate_sql
        operand2.inequality_predicate_sql
      end
    end

    class GreaterThanOrEqualTo < Binary
      def predicate_sql; '>=' end
    end

    class GreaterThan < Binary
      def predicate_sql; '>' end
    end

    class LessThanOrEqualTo < Binary
      def predicate_sql; '<=' end
    end

    class LessThan < Binary
      def predicate_sql; '<' end
    end

    class Match < Binary
      def predicate_sql; 'LIKE' end
    end

    class NotMatch < Binary
      def predicate_sql; 'NOT LIKE' end
    end

    class In < Binary
      def to_sql(formatter = nil)
        if operand2.is_a?(Range) && operand2.exclude_end?
          GreaterThanOrEqualTo.new(operand1, operand2.begin).and(
            LessThan.new(operand1, operand2.end)
          ).to_sql(formatter)
        else
          super
        end
      end

      def predicate_sql; operand2.inclusion_predicate_sql end
    end

    class NotIn < Binary
      def predicate_sql; operand2.exclusion_predicate_sql end
    end
  end
end
