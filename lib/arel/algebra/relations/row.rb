module Arel
  class Row
    attributes :relation, :tuple
    deriving :==, :initialize
    
    def [](attribute)
      tuple[relation.position_of(attribute)]
    end
    
    def slice(*attributes)
      Row.new(relation, attributes.inject([]) do |cheese, attribute|
        cheese << self[attribute]
        cheese
      end)
    end
    
    def bind(relation)
      Row.new(relation, tuple)
    end
    
    def combine(other, relation)
      Row.new(relation, tuple + other.tuple)
    end
  end
end