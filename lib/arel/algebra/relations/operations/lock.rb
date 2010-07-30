module Arel
  class Lock < Compound
    attr_reader :locked

    def initialize(relation, locked)
      super(relation)
      @locked = true == locked ? " FOR UPDATE" : locked
    end
  end
end
