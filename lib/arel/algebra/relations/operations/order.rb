module Arel
  class Order < Compound
    attr_reader :orderings

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

    def engine
      engine   = relation.engine

      # Temporary check of whether or not the engine supports where.
      if engine.respond_to?(:supports) && !engine.supports(:ordering)
        Memory::Engine.new
      else
        engine
      end
    end

    def eval
      unoperated_rows.sort do |row1, row2|
        ordering = orders.detect { |o| o.eval(row1, row2) != 0 } || orders.last
        ordering.eval(row1, row2)
      end
    end
  end
end
