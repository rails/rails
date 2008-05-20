module Arel
  class Project < Compound
    attributes :relation, :projections
    deriving :==
    
    def initialize(relation, *projections, &block)
      @relation = relation
      @projections = (projections + (block_given?? [yield(self)] : [])).collect { |p| p.bind(relation) }
    end

    def attributes
      @attributes ||= projections.collect { |p| p.bind(self) }
    end
    
    def aggregation?
      attributes.any?(&:aggregation?)
    end
  end
end