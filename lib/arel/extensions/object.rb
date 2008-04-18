class Object  
  def bind(relation)
    Arel::Value.new(self, relation)
  end
  
  def to_sql(formatter = nil)
    formatter.scalar self
  end
  
  def equality_predicate_sql
    '='
  end
  
  def metaclass
    class << self
      self
    end
  end
end