module ActiveRelation
  class Take < Compound
    attr_reader :take

    def initialize(relation, take)
      @relation, @take = relation, take
    end

    def ==(other)
      relation == other.relation and
      take     == other.take
    end

    def descend(&block)
      Take.new(relation.descend(&block), take)
    end
  end
end