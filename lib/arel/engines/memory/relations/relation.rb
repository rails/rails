module Arel
  class Relation
    def position_of(attribute)
      attributes.index(self[attribute])
    end
  end
end