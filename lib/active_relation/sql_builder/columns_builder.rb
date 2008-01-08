class ColumnsBuilder < SqlBuilder
  def initialize(&block)
    @columns = []
    super(&block)
  end
  
  def to_s
    @columns.join(', ')
  end
  
  def column(table, column, aliaz = nil)
    @columns << "#{quote_table_name(table)}.#{quote_column_name(column)}"
  end
  
  delegate :blank?, :to => :@columns
end