module Arel
  class Project < Compound
    attributes :relation, :projections
    deriving :==

    def initialize(relation, *projections, &block)
      @relation = relation
      @projections = (projections + arguments_from_block(relation, &block)) \
        .collect { |p| p.bind(relation) }
    end

    def attributes
      @attributes ||= Header.new(projections).bind(self)
    end

    def externalizable?
      attributes.any? { |a| a.respond_to?(:aggregation?) && a.aggregation? } || relation.externalizable?
    end
  end
end
