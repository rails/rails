module ActiveRelation
  class Rename < Compound
    attr_reader :autonym, :pseudonym

    def initialize(relation, pseudonyms)
      @autonym, @pseudonym = pseudonyms.shift
      @relation = pseudonyms.empty?? relation : Rename.new(relation, pseudonyms)
    end

    def ==(other)
      relation == other.relation and autonym == other.autonym and pseudonym == other.pseudonym
    end

    def qualify
      Rename.new(relation.qualify, autonym.qualify => self.pseudonym)
    end

    protected
    def projections
      relation.send(:projections).collect(&method(:substitute))
    end
    
    def attribute(name)
      case
      when name == pseudonym then autonym.as(pseudonym)
      when relation[name] == autonym then nil
      else relation[name]
      end
    end

    private
    def substitute(attribute)
      attribute == autonym ? attribute.as(pseudonym) : attribute
    end
  end
end