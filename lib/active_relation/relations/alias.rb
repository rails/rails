module ActiveRelation
  class Alias < Compound
    attr_reader :alias

    def initialize(relation, aliaz)
      @relation, @alias = relation, aliaz
    end
    
    def aliased_prefix_for(attribute)
      self[attribute] and @alias
    end
    
    def descend(&block)
      Alias.new(relation.descend(&block), @alias)
    end

    def ==(other)
      self.class == other.class and
      relation   == other.relation and
      @alias     == other.alias
    end
  end
end