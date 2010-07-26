module Arel
  class Order < Compound
    attr_reader :orderings
    requires   :ordering

    def initialize(relation, *orderings, &block)
      super(relation)
      @orderings = (orderings + arguments_from_block(relation, &block)) \
        .collect { |o| o.bind(relation) }
    end

    def == other
      super ||
        Order === other &&
        relation == other.relation &&
        orderings == other.orderings
    end

    # TESTME
    def orders
      # QUESTION - do we still need relation.orders ?
      (orderings + relation.orders).collect { |o| o.bind(self) }.collect { |o| o.to_ordering }
    end
  end
end
