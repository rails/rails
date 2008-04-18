class Hash
  def bind(relation)
    inject({}) do |bound, (key, value)|
      bound.merge(key.bind(relation) => value.bind(relation))
    end
  end
end