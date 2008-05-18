module Arel
  class Predicate
    def ==(other)
      self.class == other.class
    end
  end

  class Binary < Predicate
    attr_reader :operand1, :operand2

    def initialize(operand1, operand2)
      @operand1, @operand2 = operand1, operand2
    end

    def ==(other)
      super and @operand1 == other.operand1 and @operand2 == other.operand2
    end
    
    def bind(relation)
      self.class.new(relation[operand1] || operand1, relation[operand2] || operand2)
    end
    
    def to_sql(formatter = nil)
      "#{operand1.to_sql} #{predicate_sql} #{operand1.format(operand2)}"
    end
    alias_method :to_s, :to_sql
  end

  class Equality < Binary
    def ==(other)
      Equality == other.class and
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