module ActiveRelation
  class Projection < Compound
    attr_reader :projections
    alias_method :attributes, :projections
    
    def initialize(relation, *projections)
      @relation, @projections = relation, projections
    end

    def ==(other)
      self.class == other.class and relation == other.relation and projections == other.projections
    end

    def qualify
      Projection.new(relation.qualify, *projections.collect(&:qualify))
    end
  end
end