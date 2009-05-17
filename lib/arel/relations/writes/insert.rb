module Arel
  class Insert < Compound
    attributes :relation, :record
    deriving :==

    def initialize(relation, record)
      @relation, @record = relation, record.bind(relation)
    end

    def call
      engine.create(self)
    end
  end
end
