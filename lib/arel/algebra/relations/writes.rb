module Arel
  class Action < Compound
    def == other
      super || self.class === other && @relation == other.relation
    end
  end

  class Deletion < Action
    def call
      engine.delete(self)
    end
  end

  class Insert < Action
    attr_reader :record

    def initialize(relation, record)
      super(relation)
      @record = record.bind(relation)
    end

    def call
      engine.create(self)
    end

    def == other
      super && @record == other.record
    end
  end

  class Update < Insert
    alias :assignments :record

    def call
      engine.update(self)
    end
  end
end
