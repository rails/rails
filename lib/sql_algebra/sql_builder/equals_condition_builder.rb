class EqualsConditionBuilder < SqlBuilder
  def initialize(&block)
    @operands = []
    super(&block)
  end
  
  def column(table, column, aliaz = nil)
    @operands << (aliaz ? aliaz : "#{table}.#{column}")
  end
  
  def value(value)
    @operands << value
  end
  
  def to_s
    "#{@operands[0]} = #{@operands[1]}"
  end
end