module ActiveRelation
  class Range < Compound
    attr_reader :range

    def initialize(relation, range)
      @relation, @range = relation, range
    end

    def ==(other)
      relation == other.relation and
      range    == other.range
    end

    def limit
      range.end - range.begin + 1
    end

    def offset
      range.begin
    end
    
    def descend(&block)
      Range.new(relation.descend(&block), range)
    end
  end
end