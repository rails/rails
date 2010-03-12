module Arel
  class Where < Compound
    attributes :relation, :predicate
    deriving :==

    def initialize(relation, *predicates, &block)
      predicate = block_given?? yield(relation) : predicates.shift
      @relation = predicates.empty?? relation : Where.new(relation, *predicates)
      @predicate = predicate.bind(@relation)
    end

    def engine
      # Temporary check of whether or not the engine supports where.
      if relation.engine.respond_to?(:supports) && !relation.engine.supports(:where)
        Memory::Engine.new
      else
        relation.engine
      end
    end

    def wheres
      @wheres ||= (relation.wheres + [predicate]).collect { |p| p.bind(self) }
    end
  end
end
