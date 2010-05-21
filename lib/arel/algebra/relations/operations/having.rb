module Arel
  class Having < Compound
    attributes :relation, :predicates
    deriving   :==
    requires   :restricting

    def initialize(relation, *predicates, &block)
      predicates = [yield(relation)] + predicates if block_given?
      @predicates = predicates.map { |p| p.bind(relation) }
      @relation   = relation
    end

    def havings
      @havings ||= relation.havings + predicates
    end
  end
end
