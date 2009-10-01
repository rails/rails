module Arel
  class Ordering
    delegate :relation, :to => :attribute

    def bind(relation)
      self.class.new(attribute.bind(relation))
    end

    def to_ordering
      self
    end
  end

  class Ascending  < Ordering
    attributes :attribute
    deriving :initialize, :==
  end

  class Descending < Ordering
    attributes :attribute
    deriving :initialize, :==
  end
end
