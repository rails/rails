module ActiveRelation
  class Alias < Compound
    attr_reader :alias
    alias_method :name, :alias

    def initialize(relation, aliaz)
      @relation, @alias = relation, aliaz
    end
      
    def attributes
      relation.attributes.collect { |a| a.substitute(self) }
    end

    def ==(other)
      relation == other.relation and @alias == other.alias
    end
    
    protected
    def attribute(name)
      if unaliased_attribute = relation[name]
        unaliased_attribute.substitute(self)
      end
    end
  end
end