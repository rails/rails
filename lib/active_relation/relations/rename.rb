module ActiveRelation
  class Rename < Compound
    attr_reader :attribute, :pseudonym

    def initialize(relation, pseudonyms)
      @attribute, @pseudonym = pseudonyms.shift
      @relation = pseudonyms.empty?? relation : Rename.new(relation, pseudonyms)
    end

    def ==(other)
      self.class == other.class and relation == other.relation and attribute == other.attribute and pseudonym == other.pseudonym
    end

    def qualify
      Rename.new(relation.qualify, attribute.qualify => pseudonym)
    end
    
    def attributes
      relation.attributes.collect(&method(:substitute))
    end
    
    protected
    def attribute_for_name(name)
      case
      when referring_by_autonym?(name) then nil
      when referring_by_pseudonym?(name) then attribute.as(pseudonym).substitute(self)
      else (a = relation[name]) && a.substitute(self)
      end
    end
    
    def attribute_for_attribute(attribute)
      attribute.relation == self ? attribute : substitute(relation[attribute])
    end
    
    def attribute_for_expression(expression)
      expression.relation == self ? expression : substitute(relation[expression])
    end

    private
    def substitute(attribute)
      (relation[attribute] == relation[self.attribute] ? attribute.as(pseudonym) : attribute).substitute(self) if attribute
    end

    def referring_by_autonym?(name)
      relation[name] == relation[attribute]
    end
    
    def referring_by_pseudonym?(name)
      name == pseudonym
    end
  end
end