module Arel
  class Having < Compound
    attr_reader :predicates

    def initialize(relation, predicates)
      super(relation)
      @predicates = predicates.map { |p| p.bind(relation) }
    end

    def havings
      @havings ||= relation.havings + predicates
    end
  end
end
