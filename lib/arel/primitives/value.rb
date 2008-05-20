module Arel
  class Value
    attributes :value, :relation
    deriving :initialize, :==
    delegate :inclusion_predicate_sql, :equality_predicate_sql, :to => :value
    
    
    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation))
    end
    
    def bind(relation)
      Value.new(value, relation)
    end
  end
end