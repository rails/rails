module Arel
  class Order < Compound
    attributes :relation, :orderings
    deriving :==
    
    def initialize(relation, *orderings, &block)
      @relation = relation
      @orderings = (orderings + (block_given?? [yield(self)] : [])).collect { |o| o.bind(relation) }
    end

    # TESTME
    def orders
      (orderings + relation.orders).collect { |o| o.bind(self) }
    end
  end
end