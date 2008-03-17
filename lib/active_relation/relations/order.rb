module ActiveRelation
  class Order < Compound
    attr_reader :order

    def initialize(relation, *orders)
      @order = orders.pop
      @relation = orders.empty?? relation : Order.new(relation, *orders)
    end

    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      orders      == other.orders
    end

    def descend(&block)
      Order.new(relation.descend(&block), *orders.collect(&block))
    end
    
    def orders
      relation.orders + [order]
    end
  end
end