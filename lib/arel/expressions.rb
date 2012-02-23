module Arel
  module Expressions
    def count distinct = false
      Nodes::Count.new [self], distinct
    end

    def sum
      Nodes::Sum.new [self], Nodes::SqlLiteral.new('sum_id')
    end

    def maximum
      Nodes::Max.new [self], Nodes::SqlLiteral.new('max_id')
    end

    def minimum
      Nodes::Min.new [self], Nodes::SqlLiteral.new('min_id')
    end

    def average
      Nodes::Avg.new [self], Nodes::SqlLiteral.new('avg_id')
    end

    def extract field
      Nodes::Extract.new [self], field
    end
  end
end
