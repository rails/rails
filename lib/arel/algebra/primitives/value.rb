module Arel
  class Value
    attributes :value, :relation
    deriving :initialize, :==

    def bind(relation)
      Value.new(value, relation)
    end

    def aggregation?
      false
    end

    def to_attribute
      value
    end
  end
end
