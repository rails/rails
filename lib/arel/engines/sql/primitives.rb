module Arel
  class SqlLiteral < String
    def relation
      nil
    end

    def to_sql(formatter = nil)
      self
    end

    include Attribute::Expressions
  end

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

  class Ordering
    def to_sql(formatter = Sql::OrderClause.new(relation))
      formatter.ordering self
    end
  end

  class Ascending < Ordering
    def direction_sql; 'ASC' end
  end

  class Descending < Ordering
    def direction_sql; 'DESC' end
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
