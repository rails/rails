module ActiveRelation
  class Projection < Compound
    attr_reader :projections
    
    def initialize(relation, *projections)
      @relation, @projections = relation, projections
    end

    def attributes
      projections.collect { |p| p.bind(self) }
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      projections == other.projections
    end

    def qualify
      Projection.new(relation.qualify, *projections.collect(&:qualify))
    end
  end
end