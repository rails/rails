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

  class Expression < Attribute
    def to_sql(formatter = Sql::SelectClause.new(relation))
      formatter.expression self
    end
  end

  class Value
    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation))
    end
  end
end