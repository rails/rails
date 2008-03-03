class Object
  def qualify
    self
  end
  
  def bind(relation)
    self
  end
  
  def to_sql(strategy = self.strategy)
    strategy.scalar self
  end
  
  def strategy
    ActiveRelation::Sql::Scalar.new(ActiveRelation::Table.engine)
  end
  
  def metaclass
    class << self
      self
    end
  end
end