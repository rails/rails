module ActiveRelation
  class Order < Compound
    attr_reader :orders

    def initialize(relation, *orders)
      @relation, @orders = relation, orders
    end

    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      orders      == other.orders
    end

    def descend(&block)
      Order.new(relation.descend(&block), *orders.collect(&block))
    end
  end
end