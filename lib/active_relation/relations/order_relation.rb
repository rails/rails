class OrderRelation < CompoundRelation
  attr_reader :relation, :orders
  
  def initialize(relation, *orders)
    @relation, @orders = relation, orders
  end
  
  def ==(other)
    relation == other.relation and orders.eql?(other.orders)
  end
  
  def qualify
    OrderRelation.new(relation.qualify, *orders.collect { |o| o.qualify })
  end
end