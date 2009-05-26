module Arel
  class Group < Compound
    attributes :relation, :groupings
    deriving :==

    def initialize(relation, *groupings, &block)
      @relation = relation
      @groupings = (groupings + arguments_from_block(relation, &block)) \
        .collect { |g| g.bind(relation) }
    end
  end
end
