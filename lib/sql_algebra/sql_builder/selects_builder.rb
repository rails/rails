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
    @selects << "#{table}.#{column}" + (aliaz ? " AS #{aliaz}" : '')
  end
  
  delegate :blank?, :to => :@selects
end