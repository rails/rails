module Arel
  class Where < Compound
    attributes :relation, :predicate
    deriving   :==
    requires   :restricting

    def initialize(relation, *predicates, &block)
      predicate = block_given?? yield(relation) : predicates.shift
      @relation = predicates.empty?? relation : Where.new(relation, *predicates)
      @predicate = predicate.bind(@relation)
    end

    def wheres
      @wheres ||= (relation.wheres + [predicate]).collect { |p| p.bind(self) }
    end
  end
end
