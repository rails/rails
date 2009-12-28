module Arel
  class Having < Compound
    attributes :relation, :havings
    deriving :==

    def initialize(relation, *havings, &block)
      @relation = relation
      @havings = (havings + arguments_from_block(relation, &block)) \
        .collect { |g| g.bind(relation) }
    end
  end
end

