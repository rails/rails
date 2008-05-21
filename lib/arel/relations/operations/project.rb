module Arel
  class Project < Compound
    attributes :relation, :projections
    deriving :==
    
    def initialize(relation, *projections, &block)
      @relation = relation
      @projections = (projections + (block_given?? [yield(relation)] : [])).collect { |p| p.bind(relation) }
    end

    def attributes
      @attributes ||= projections.collect { |p| p.bind(self) }
    end
    
    def externalizable?
      attributes.any?(&:aggregation?) or relation.externalizable?
    end
  end
end