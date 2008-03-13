module ActiveRelation
  class Value
    attr_reader :value, :relation
    
    def initialize(value, relation)
      @value, @relation = value, relation
    end
    
    def to_sql(strategy = Sql::Predicate.new(relation.engine))
      strategy.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation.engine))
    end
    
    def ==(other)
      value == other.value
    end
    
    def qualify
      self
    end
  end
end