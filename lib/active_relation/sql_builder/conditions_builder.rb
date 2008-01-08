class ConditionsBuilder < SqlBuilder
  def initialize(&block)
    @conditions = []
    super(&block)
  end
  
  def equals(&block)
    @conditions << EqualsConditionBuilder.new(&block)
  end
  
  def value(value)
    @conditions << value
  end
      
  def to_s
    @conditions.join(' AND ')
  end
  
  delegate :blank?, :to => :@conditions
end