module Arel
  class Expression < Attribute
    def to_sql(formatter = Sql::SelectClause.new(relation))
      formatter.expression self
    end
  end
end