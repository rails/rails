class Object  
  def bind(relation)
    ActiveRelation::Value.new(self, relation)
  end
  
  def to_sql(strategy = nil)
    strategy.scalar self
  end
  
  def metaclass
    class << self
      self
    end
  end
end