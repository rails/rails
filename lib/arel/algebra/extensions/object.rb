class Object
  def bind(relation)
    Arel::Value.new(self, relation)
  end

  def find_correlate_in(relation)
    bind(relation)
  end

  def metaclass
    class << self
      self
    end
  end
end
