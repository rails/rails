module Arel
  class Update < Compound
    attributes :relation, :assignments
    deriving :==

    def initialize(relation, assignments)
      @relation, @assignments = relation, assignments
    end

    def call
      engine.update(self)
    end
  end
end
