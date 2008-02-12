module ActiveRelation
  class Predicate
    def ==(other)
      self.class == other.class
    end
  end

  class Binary < Predicate
    attr_reader :attribute, :operand

    def initialize(attribute, operand)
      @attribute, @operand = attribute, operand
    end

    def ==(other)
      super and @attribute == other.attribute and @operand == other.operand
    end

    def qualify
      self.class.new(attribute.qualify, operand.qualify)
    end
    
    def bind(relation)
      self.class.new(attribute.bind(relation), operand.bind(relation))
    end

    def to_sql(strategy = Sql::Predicate.new)
      "#{attribute.to_sql(strategy)} #{predicate_sql} #{operand.to_sql(strategy)}"
    end
  end

  class Equality < Binary
    def ==(other)
      self.class == other.class and
        ((attribute == other.attribute and operand == other.operand) or
         (attribute == other.operand and operand == other.attribute))
    end

    protected
    def predicate_sql
      '='
    end
  end

  class GreaterThanOrEqualTo < Binary
    protected
    def predicate_sql
      '>='
    end
  end

  class GreaterThan < Binary
    protected
    def predicate_sql
      '>'
    end
  end

  class LessThanOrEqualTo < Binary
    protected
    def predicate_sql
      '<='
    end
  end

  class LessThan < Binary
    protected
    def predicate_sql
      '<'
    end
  end

  class Match < Binary
    alias_method :regexp, :operand

    def initialize(attribute, regexp)
      @attribute, @regexp = attribute, regexp
    end
  end

  class RelationInclusion < Binary
    alias_method :relation, :operand
    
    protected
    def predicate_sql
      'IN'
    end
  end
end