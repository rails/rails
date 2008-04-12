module ActiveRelation
  class Skip < Compound
    attr_reader :skipped

    def initialize(relation, skipped)
      @relation, @skipped = relation, skipped
    end

    def ==(other)
      relation == other.relation and
      skipped  == other.skipped
    end

    def descend(&block)
      Skip.new(relation.descend(&block), skipped)
    end
  end
end