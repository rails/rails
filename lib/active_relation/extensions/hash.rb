class Hash
  def bind(relation)
    descend { |x| x.bind(relation) }
  end
  
  def descend(&block)
    inject({}) do |descendent, (key, value)|
      descendent.merge(yield(key) => yield(value))
    end
  end
end