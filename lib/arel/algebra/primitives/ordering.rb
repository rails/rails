module Arel
  class Ordering
    attributes :attribute
    deriving :initialize, :==
    delegate :relation, :to => :attribute
    
    def bind(relation)
      self.class.new(attribute.bind(relation))
    end
    
    def to_ordering
      self
    end
  end
  
  class Ascending  < Ordering; end
  class Descending < Ordering; end
end