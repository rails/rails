module Arel
  class Group < Compound
    attr_reader :groupings

    def initialize(relation, *groupings, &block)
      super(relation)
      @groupings = (groupings + arguments_from_block(relation, &block)) \
        .collect { |g| g.bind(relation) }
    end

    def == other
      super ||
        self.class === other &&
        @relation == other.relation &&
        @groupings == other.groupings
    end

    def eval
      raise NotImplementedError
    end
  end
end
