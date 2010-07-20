module Arel
  class Ordering < Struct.new(:attribute)
    delegate :relation, :to => :attribute

    def bind(relation)
      self.class.new(attribute.bind(relation))
    end

    def to_ordering
      self
    end

    def == other
      super || (self.class === other && attribute == other.attribute)
    end
  end

  class Ascending  < Ordering
  end
  class Descending < Ordering
  end
end
