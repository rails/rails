class OrderBuilder < SqlBuilder
  def initialize(&block)
    @orders = []
    super(&block)
  end
  
  def column(table, column, aliaz = nil)
    @orders << (aliaz ? quote(aliaz) : "#{quote_table_name(table)}.#{quote_column_name(column)}")
  end
  
  def to_s
    @orders.join(', ')
  end
  
  delegate :blank?, :to => :@orders
end