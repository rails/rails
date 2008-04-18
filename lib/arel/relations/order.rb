module Arel
  class Order < Compound
    attr_reader :orders

    def initialize(relation, *orders)
      @relation, @orders = relation, orders.collect { |o| o.bind(relation) }
    end

    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      orders      == other.orders
    end
  end
end