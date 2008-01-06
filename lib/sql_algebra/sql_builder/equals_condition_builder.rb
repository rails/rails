class EqualsConditionBuilder < SqlBuilder
  def initialize(&block)
    @operands = []
    super(&block)
  end
  
  def column(table, column, aliaz = nil)
    @operands << "#{quote_table_name(table)}.#{quote_column_name(column)}"
  end
  
  def value(value)
    @operands << value
  end
  
  def to_s
    "#{@operands[0]} = #{@operands[1]}"
  end
end