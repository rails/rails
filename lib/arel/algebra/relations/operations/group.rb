module Arel
  class Group < Compound
    attr_reader :groupings

    def initialize(relation, groupings)
      super(relation)
      @groupings = groupings.collect { |g| g.bind(relation) }
    end

    def eval
      raise NotImplementedError
    end
  end
end
