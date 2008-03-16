module ActiveRelation
  class Value
    attr_reader :value, :relation
    
    delegate :predicate_sql, :to => :value
    
    def initialize(value, relation)
      @value, @relation = value, relation
    end
    
    def to_sql(formatter = Sql::WhereCondition.new(relation.engine))
      formatter.value value
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