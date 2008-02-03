module ActiveRelation
  class Alias < Compound
    attr_reader :alias

    def initialize(relation, aliaz)
      @relation, @alias = relation, aliaz
    end
      
    def ==(other)
      relation == other.relation and @alias == other.alias
    end
  end
end