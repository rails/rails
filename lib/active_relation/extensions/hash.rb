class Hash
  def alias(&block)
    inject({}) do |aliased, (key, value)|
      aliased.merge(yield(key) => value)
    end
  end
  
  def to_sql(strategy = nil)
    "(#{values.collect(&:to_sql).join(', ')})"
  end
end