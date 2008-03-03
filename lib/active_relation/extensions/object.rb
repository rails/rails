class Object  
  def bind(relation)
    ActiveRelation::Scalar.new(self, relation)
  end
  
  def metaclass
    class << self
      self
    end
  end
end