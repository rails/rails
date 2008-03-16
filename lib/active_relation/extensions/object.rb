class Object  
  def bind(relation)
    ActiveRelation::Value.new(self, relation)
  end
  
  def metaclass
    class << self
      self
    end
  end
end