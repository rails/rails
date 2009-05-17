module Arel
  class Row
    attributes :relation, :tuple
    deriving :==, :initialize

    def [](attribute)
      attribute.type_cast(tuple[relation.position_of(attribute)])
    end

    def slice(*attributes)
      Row.new(relation, attributes.inject([]) do |cheese, attribute|
        # FIXME TESTME method chaining
        cheese << tuple[relation.relation.position_of(attribute)]
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
