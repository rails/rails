module ActiveRelation
  class Grouping < Compound
    attr_reader :expressions, :groupings

    def initialize(relation, *groupings)
      @relation, @groupings = relation, groupings.collect { |g| g.bind(relation) }
    end

    def ==(other)
      self.class  == other.class      and
      relation    == other.relation   and
      groupings   == other.groupings
    end

    def aggregation?
      true
    end
  end
end