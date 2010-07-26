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
end
