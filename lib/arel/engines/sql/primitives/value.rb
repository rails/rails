module Arel
  class Value
    def to_sql(formatter = Sql::WhereCondition.new(relation))
      formatter.value value
    end

    def format(object)
      object.to_sql(Sql::Value.new(relation))
    end
  end
end