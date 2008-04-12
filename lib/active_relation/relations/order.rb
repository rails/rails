module ActiveRelation
  class Order < Compound
    attr_reader :ordering

    def initialize(relation, *orders)
      ordering = orders.pop
      @relation = orders.empty?? relation : Order.new(relation, *orders)
      @ordering = ordering.bind(@relation)
    end

    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      ordering    == other.ordering
    end
    
    def orders
      relation.orders + [ordering]
    end
  end
end