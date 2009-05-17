module Arel

  class Binary < Predicate
    def eval(row)
      operand1.eval(row).send(operator, operand2.eval(row))
    end
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

  class Equality < Binary
  end

  class GreaterThanOrEqualTo < Binary
  end

  class GreaterThan < Binary
  end

  class LessThanOrEqualTo < Binary
  end

  class LessThan < Binary
    def operator; :< end
  end

  class Match < Binary
  end

  class In < Binary
  end
end
