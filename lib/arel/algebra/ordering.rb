module Arel
  class Ordering < Struct.new(:attribute)
    delegate :relation, :to => :attribute

    def bind(relation)
      self.class.new(attribute.bind(relation))
    end

    def to_ordering
      self
    end

    def eval(row1, row2)
      (attribute.eval(row1) <=> attribute.eval(row2)) * direction
    end

    def to_sql(formatter = Sql::OrderClause.new(relation))
      formatter.ordering self
    end
  end

  class Ascending  < Ordering
    def direction; 1 end
    def direction_sql; 'ASC' end
  end

  class Descending < Ordering
    def direction_sql; 'DESC' end
    def direction; -1 end
  end
end
