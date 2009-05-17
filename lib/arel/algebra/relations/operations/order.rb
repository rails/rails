module Arel
  class Order < Compound
    attributes :relation, :orderings
    deriving :==
    
    def initialize(relation, *orderings, &block)
      @relation = relation
      @orderings = (orderings + (block_given?? [yield(relation)] : [])).collect { |o| o.bind(relation) }
    end

    # TESTME
    def orders
      # QUESTION - do we still need relation.orders ?
      (orderings + relation.orders).collect { |o| o.bind(self) }.collect { |o| o.to_ordering }
    end
  end
end