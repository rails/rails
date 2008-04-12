module ActiveRelation
  class Skip < Compound
    attr_reader :skip

    def initialize(relation, skip)
      @relation, @skip = relation, skip
    end

    def ==(other)
      relation == other.relation and
      skip     == other.skip
    end

    def descend(&block)
      Skip.new(relation.descend(&block), skip)
    end
  end
end