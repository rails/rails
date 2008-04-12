module ActiveRelation
  class Alias < Compound
    attr_reader :alias

    def initialize(relation, aliaz)
      @relation, @alias = relation, aliaz
    end
    
    def alias?
      true
    end

    def ==(other)
      self.class == other.class and
      relation   == other.relation and
      @alias     == other.alias
    end
  end
end