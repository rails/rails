module Arel
  class From < Compound
    attr_reader :sources

    def initialize relation, sources
      super(relation)
      @sources = sources
    end

    def eval
      unoperated_rows[sources..-1]
    end
  end
end
