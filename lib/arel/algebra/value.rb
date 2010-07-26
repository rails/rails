module Arel
  class Value
    attr_reader :value, :relation

    def initialize value, relation
      @value = value
      @relation = relation
    end

    def == other
      super ||
        Value === other &&
        value == other.value &&
        relation == other.relation
    end

    def eval(row)
      value
    end

    def bind(relation)
      Value.new(value, relation)
    end

    def to_ordering
      self
    end

    def inclusion_predicate_sql
      value.inclusion_predicate_sql
    end

    def exclusion_predicate_sql
      value.exclusion_predicate_sql
    end

    def equality_predicate_sql
      value.equality_predicate_sql
    end

    def inequality_predicate_sql
      value.inequality_predicate_sql
    end

    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation))
    end
  end
end
