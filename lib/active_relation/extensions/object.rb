class Object
  def self.hash_on(delegatee)
    def eql?(other)
      self == other
    end
    
    delegate :hash, :to => delegatee
  end
  
  def bind(relation)
    ActiveRelation::Value.new(self, relation)
  end
  
  def metaclass
    class << self
      self
    end
  end
end