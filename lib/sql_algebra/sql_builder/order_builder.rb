class OrderBuilder < SqlBuilder
  def initialize(&block)
    @orders = []
    super(&block)
  end
  
  def column(table, column, aliaz = nil)
    @orders << (aliaz ? aliaz : "#{table}.#{column}")
  end
  
  def to_s
    @orders.join(', ')
  end
  
  delegate :blank?, :to => :@orders
end