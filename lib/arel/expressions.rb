module Arel
  module Expressions
    def count distinct = false
      Nodes::Count.new [self], distinct
    end

    def sum(alias_as = "sum_id")
      Nodes::Sum.new [self], node_alias(alias_as)
    end

    def maximum(alias_as = "max_id")
      Nodes::Max.new [self], node_alias(alias_as)
    end

    def minimum(alias_as = "min_id")
      Nodes::Min.new [self], node_alias(alias_as)
    end

    def average(alias_as = "avg_id")
      Nodes::Avg.new [self], node_alias(alias_as)
    end

    def extract field
      Nodes::Extract.new [self], field
    end

  private

    def node_alias(alias_as)
      alias_as.nil? ? nil : Nodes::SqlLiteral.new(alias_as)
    end

  end
end
