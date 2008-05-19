module Arel
  class Grouping < Compound
    attr_reader :groupings

    def initialize(relation, *groupings)
      @relation, @groupings = relation, groupings.collect { |g| g.bind(relation) }
    end

    def ==(other)
      Grouping    === other          and
      relation    ==  other.relation and
      groupings   ==  other.groupings
    end

    def aggregation?
      true
    end
  end
end