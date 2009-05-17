require 'set'

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
end