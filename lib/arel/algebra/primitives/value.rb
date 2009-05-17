module Arel
  class Value
    attributes :value, :relation
    deriving :initialize, :==
    delegate :inclusion_predicate_sql, :equality_predicate_sql, :to => :value

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
