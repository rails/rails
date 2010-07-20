module Arel
  class From < Compound
    attr_reader :sources

    def initialize relation, sources
      super(relation)
      @sources = sources
    end
  end
end
