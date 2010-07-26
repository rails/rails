module Arel
  class Lock < Compound
    attr_reader :locked

    def initialize(relation, locked)
      super(relation)
      @locked   = locked.blank? ? " FOR UPDATE" : locked
    end

    def == other
      super || Lock === other &&
               relation == other.relation &&
               locked == other.locked
    end
  end
end
