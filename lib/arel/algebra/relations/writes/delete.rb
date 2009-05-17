module Arel
  class Deletion < Compound
    attributes :relation
    deriving :initialize, :==

    def call
      engine.delete(self)
    end
  end
end
