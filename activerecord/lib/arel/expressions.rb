# frozen_string_literal: true

module Arel
  module Expressions
    def count(distinct = false)
      Nodes::Count.new [self], distinct
    end

    def sum
      Nodes::Sum.new [self]
    end

    def maximum
      Nodes::Max.new [self]
    end

    def minimum
      Nodes::Min.new [self]
    end

    def average
      Nodes::Avg.new [self]
    end

    def extract(field)
      Nodes::Extract.new [self], field
    end
  end
end
