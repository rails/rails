module ActiveRelation
  class Order < Compound
    attr_reader :orders

    def initialize(relation, *orders)
      @relation, @orders = relation, orders
    end

    def ==(other)
      relation == other.relation and
      orders   == other.orders
    end

    def qualify
      Order.new(relation.qualify, *orders.collect(&:qualify))
    end
  end
end