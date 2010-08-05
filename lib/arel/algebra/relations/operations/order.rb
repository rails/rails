module Arel
  class Order < Compound
    attr_reader :orderings

    def initialize(relation, orderings)
      super(relation)
      @orderings = orderings.collect { |o| o.bind(relation) }
    end

    # TESTME
    def orders
      # QUESTION - do we still need relation.orders ?
      (orderings + relation.orders).collect { |o| o.bind(self) }.collect { |o| o.to_ordering }
    end

    def eval
      unoperated_rows.sort do |row1, row2|
        ordering = orders.detect { |o| o.eval(row1, row2) != 0 } || orders.last
        ordering.eval(row1, row2)
      end
    end
  end
end
