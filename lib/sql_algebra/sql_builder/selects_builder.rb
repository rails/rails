class SelectsBuilder < SqlBuilder
  def initialize(&block)
    @selects = []
    super(&block)
  end
  
  def to_s
    @selects.join(', ')
  end
  
  def all
    @selects << :*
  end
  
  def column(table, column, aliaz = nil)
    @selects << "#{quote_table_name(table)}.#{quote_column_name(column)}" + (aliaz ? " AS #{quote(aliaz)}" : '')
  end
  
  delegate :blank?, :to => :@selects
end