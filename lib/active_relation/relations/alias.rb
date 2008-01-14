module ActiveRelation
  class Alias < Compound
    attr_reader :alias
    alias_method :name, :alias

    def initialize(relation, aliaz)
      @relation, @alias = relation, aliaz
    end
      
    def attributes
      relation.attributes.collect(&method(:substitute))
    end

    def ==(other)
      relation == other.relation and self.alias == other.alias
    end
    
    protected
    def table_sql
      "#{quote_table_name(relation.name)} AS #{quote_table_name(@alias)}"
    end
    
    def attribute(name)
      if unaliased_attribute = relation[name]
        substitute(unaliased_attribute)
      end
    end
    
    private
    def substitute(attribute)
      Attribute.new(self, attribute.name, attribute.alias)
    end
  end
end