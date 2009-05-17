class Hash
  def bind(relation)
    inject({}) do |bound, (key, value)|
      bound.merge(key.bind(relation) => value.bind(relation))
    end
  end
  
  def slice(*attributes)
    inject({}) do |cheese, (key, value)|
      cheese[key] = value if attributes.include?(key)
      cheese
    end
  end
end