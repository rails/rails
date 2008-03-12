module ActiveRelation
  class Scalar
    attr_reader :value, :relation
    
    def initialize(value, relation)
      @value, @relation = value, relation
    end
    
    def to_sql(strategy = Sql::Predicate.new(relation.engine))
      strategy.scalar value
    end

    def format(object)
      object.to_sql(Sql::Scalar.new(relation.engine))
    end
    
    def ==(other)
      value == other.value
    end
    
    def qualify
      self
    end
  end
end