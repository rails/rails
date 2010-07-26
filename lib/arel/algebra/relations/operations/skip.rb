module Arel
  class Skip < Compound
    attr_reader :relation, :skipped

    def initialize relation, skipped
      super(relation)
      @skipped = skipped
    end

    def == other
      super ||
        Skip === other &&
        relation == other.relation &&
        skipped == other.skipped
    end

    def engine
      engine   = relation.engine

      # Temporary check of whether or not the engine supports where.
      if engine.respond_to?(:supports) && !engine.supports(:skipping)
        Memory::Engine.new
      else
        engine
      end
    end

    def eval
      unoperated_rows[skipped..-1]
    end
  end
end
