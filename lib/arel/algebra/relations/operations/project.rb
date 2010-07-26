module Arel
  class Project < Compound
    attr_reader :projections

    def initialize(relation, *projections, &block)
      super(relation)
      @projections = (projections + arguments_from_block(relation, &block)) \
        .collect { |p| p.bind(relation) }
    end

    def attributes
      @attributes ||= Header.new(projections).bind(self)
    end

    def externalizable?
      attributes.any? { |a| a.respond_to?(:aggregation?) && a.aggregation? } || relation.externalizable?
    end

    def == other
      super ||
        Project === other &&
        relation == other.relation &&
        projections == other.projections
    end
  end
end
