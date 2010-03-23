module Arel
  class Where < Compound
    attributes :relation, :predicates
    deriving   :==
    requires   :restricting

    def initialize(relation, *predicates, &block)
      predicates = [yield(relation)] + predicates if block_given?
      @predicates = predicates.map { |p| p.bind(relation) }
      @relation   = relation
    end

    def wheres
      @wheres ||= relation.wheres + predicates
    end
  end
end
