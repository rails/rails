module Arel
  class Project < Compound
    attr_reader :projections

    def initialize(relation, *projections)
      super(relation)
      @projections = projections.collect { |p| p.bind(relation) }
      @attributes = nil
    end

    def attributes
      @attributes ||= Header.new(projections).bind(self)
    end

    def externalizable?
      attributes.any? { |a| a.respond_to?(:aggregation?) && a.aggregation? } || relation.externalizable?
    end

    def eval
      unoperated_rows.collect { |r| r.slice(*projections) }
    end
  end
end
