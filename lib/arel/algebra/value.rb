module Arel
  class Value
    attr_reader :value, :relation

    def initialize value, relation
      @value = value
      @relation = relation
    end

    def == other
      super ||
        Value === other &&
        value == other.value &&
        relation == other.relation
    end

    def bind(relation)
      Value.new(value, relation)
    end

    def to_ordering
      self
    end
  end
end
