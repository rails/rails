module Arel
  class Attribute
    def column
      original_relation.column_for(self)
    end

    def format(object)
      object.to_sql(Sql::Attribute.new(self))
    end

    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.attribute self
    end
  end

  class Value
    delegate :inclusion_predicate_sql, :equality_predicate_sql, :to => :value

    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation))
    end
  end

  class Expression < Attribute
    def to_sql(formatter = Sql::SelectClause.new(relation))
      formatter.expression self
    end
  end

  class Count < Expression
    def function_sql; 'COUNT' end
  end

  class Distinct < Expression
    def function_sql; 'DISTINCT' end
  end

  class Sum < Expression
    def function_sql; 'SUM' end
  end

  class Maximum < Expression
    def function_sql; 'MAX' end
  end

  class Minimum < Expression
    def function_sql; 'MIN' end
  end

  class Average < Expression
    def function_sql; 'AVG' end
  end
end