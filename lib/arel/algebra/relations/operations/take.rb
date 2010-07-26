module Arel
  class Take < Compound
    attr_reader :taken

    def initialize relation, taken
      super(relation)
      @taken = taken
    end

    def == other
      super ||
        Take === other &&
        relation == other.relation &&
        taken == other.taken
    end

    def engine
      engine   = relation.engine

      # Temporary check of whether or not the engine supports where.
      if engine.respond_to?(:supports) && !engine.supports(:limiting)
        Memory::Engine.new
      else
        engine
      end
    end

    def externalizable?
      true
    end

    def eval
      unoperated_rows[0, taken]
    end
  end
end
