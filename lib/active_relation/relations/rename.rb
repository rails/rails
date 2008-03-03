module ActiveRelation
  class Rename < Compound
    attr_reader :attribute, :pseudonym

    def initialize(relation, pseudonyms)
      @attribute, @pseudonym = pseudonyms.shift
      @relation = pseudonyms.empty?? relation : Rename.new(relation, pseudonyms)
    end

    def ==(other)
      self.class == other.class     and
      relation   == other.relation  and
      attribute  == other.attribute and
      pseudonym  == other.pseudonym
    end
    
    def attributes
      relation.attributes.collect(&method(:christen))
    end
    
    def descend(&block)
      Rename.new(relation.descend(&block), yield(attribute) => pseudonym)
    end
    
    private
    def christen(attribute)
      (attribute =~ self.attribute ? attribute.as(pseudonym) : attribute).bind(self) rescue nil
    end
  end
end