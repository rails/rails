module Arel
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
    
    def to_sql(formatter = nil)
      "#{operand1.to_sql} #{predicate_sql} #{operand1.format(operand2)}"
    end
    alias_method :to_s, :to_sql
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
    def ==(other)
      Equality === other and
        ((operand1 == other.operand1 and operand2 == other.operand2) or
         (operand1 == other.operand2 and operand2 == other.operand1))
    end

    def predicate_sql
      operand2.equality_predicate_sql
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
  
  class In < Binary
    def predicate_sql; operand2.inclusion_predicate_sql end
  end
end