module Arel
  class Having < Compound
    attributes :relation, :predicates
    deriving   :==

    def initialize(relation, *predicates)
      predicates = [yield(relation)] + predicates if block_given?
      @predicates = predicates.map { |p| p.bind(relation) }
      @relation   = relation
    end

    def havings
      @havings ||= relation.havings + predicates
    end
  end
end
