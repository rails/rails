module Arel
  class Group < Compound
    attr_reader :groupings

    def initialize(relation, *groupings)
      @relation, @groupings = relation, groupings.collect { |g| g.bind(relation) }
    end

    def ==(other)
      Group       === other          and
      relation    ==  other.relation and
      groupings   ==  other.groupings
    end

    def aggregation?
      true
    end
  end
end