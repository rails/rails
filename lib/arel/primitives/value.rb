module Arel
  class Value
    attr_reader :value, :relation
    
    delegate :inclusion_predicate_sql, :equality_predicate_sql, :to => :value
    
    def initialize(value, relation)
      @value, @relation = value, relation
    end
    
    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation))
    end
    
    def ==(other)
      Value == other.class and
      value == other.value
    end
    
    def bind(relation)
      Value.new(value, relation)
    end
  end
end