module Arel
  class Projection < Compound
    attr_reader :projections
    
    def initialize(relation, *projections)
      @relation, @projections = relation, projections
    end

    def attributes
      @attributes ||= projections.collect { |p| p.bind(self) }
    end
    
    def aggregation?
      attributes.any?(&:aggregation?)
    end
    
    def ==(other)
      Projection  === other          and
      relation    ==  other.relation and
      projections ==  other.projections
    end
  end
end