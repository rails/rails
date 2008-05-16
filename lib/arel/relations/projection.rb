module Arel
  class Projection < Compound
    attr_reader :projections
    
    def initialize(relation, *projections)
      @relation, @projections = relation, projections
    end

    def attributes
      @attributes ||= projections.collect { |p| p.bind(self) }
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      projections == other.projections
    end
    
    def aggregation?
      attributes.any?(&:aggregation?)
    end
    
    def relation_for(attribute)
      self[attribute] && self || relation.relation_for(attribute)
    end
  end
end