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

    protected
    def descend(&block)
      Order.new(relation.descend(&block), *orders.collect(&block))
    end
  end
end