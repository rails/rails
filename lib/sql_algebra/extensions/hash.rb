class Hash
  def alias(&block)
    inject({}) do |aliased, (key, value)|
      aliased.merge(yield(key) => value)
    end
  end
end