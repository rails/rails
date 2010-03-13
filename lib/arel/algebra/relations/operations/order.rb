module Arel
  class Order < Compound
    attributes :relation, :orderings
    deriving   :==
    requires   :ordering

    def initialize(relation, *orderings, &block)
      @relation = relation
      @orderings = (orderings + arguments_from_block(relation, &block)) \
        .collect { |o| o.bind(relation) }
    end

    # TESTME
    def orders
      # QUESTION - do we still need relation.orders ?
      (orderings + relation.orders).collect { |o| o.bind(self) }.collect { |o| o.to_ordering }
    end
  end
end
