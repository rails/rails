module Arel
  class Expression < Attribute
    attr_reader :attribute
    alias :name :alias

    def initialize(attribute, aliaz = nil, ancestor = nil)
      super(attribute.relation, aliaz, :alias => aliaz, :ancestor => ancestor)
      @attribute = attribute
    end

    def aggregation?
      true
    end

    def to_sql(formatter = Sql::SelectClause.new(relation))
      formatter.expression self
    end

    def as(aliaz)
      self.class.new(attribute, aliaz, self)
    end

    def bind(new_relation)
      new_relation == relation ? self : self.class.new(attribute.bind(new_relation), @alias, self)
    end

    def to_attribute(relation)
      Attribute.new(relation, @alias, :ancestor => self)
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

