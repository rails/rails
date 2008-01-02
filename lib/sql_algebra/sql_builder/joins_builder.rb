class JoinsBuilder < SqlBuilder
  def initialize(&block)
    @joins = []
    super(&block)
  end
  
  def inner_join(table, &block)
    @joins << InnerJoinBuilder.new(table, &block)
  end
  
  def left_outer_join(table, &block)
    @joins << LeftOuterJoinBuilder.new(table, &block)
  end
  
  def to_s
    @joins.join(' ')
  end
end