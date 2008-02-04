module ActiveRelation
  class Alias < Compound
    attr_reader :alias
    
    def aliased_prefix_for(attribute)
      @alias
    end

    def initialize(relation, aliaz)
      @relation, @alias = relation, aliaz
    end
      
    def ==(other)
      self.class == other.class and relation == other.relation and @alias == other.alias
    end
  end
end