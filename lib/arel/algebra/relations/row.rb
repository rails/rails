module Arel
  class Row
    attr_reader :tuple, :relation

    def initialize relation, tuple
      @relation = relation
      @tuple = tuple
    end

    def [](attribute)
      attribute.type_cast(tuple[relation.position_of(attribute)])
    end

    def slice(*attributes)
      Row.new(relation, attributes.map do |attribute|
        # FIXME TESTME method chaining
        tuple[relation.relation.position_of(attribute)]
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
