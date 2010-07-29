module Arel
  class Where < Compound
    attr_reader :predicates

    def initialize(relation, predicates)
      super(relation)
      @predicates = predicates.map { |p| p.bind(relation) }
      @wheres = nil
    end

    def wheres
      @wheres ||= relation.wheres + predicates
    end

    def == other
      super ||
        Where === other &&
        relation == other.relation &&
        predicates == other.predicates
    end

    def engine
      engine   = relation.engine

      # Temporary check of whether or not the engine supports where.
      if engine.respond_to?(:supports) && !engine.supports(:restricting)
        Memory::Engine.new
      else
        engine
      end
    end

    def eval
      unoperated_rows.select { |row| predicates.all? { |p| p.eval(row) } }
    end
  end
end
