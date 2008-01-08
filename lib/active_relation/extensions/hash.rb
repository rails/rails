class Hash
  def alias(&block)
    inject({}) do |aliased, (key, value)|
      aliased.merge(yield(key) => value)
    end
  end
  
  def to_sql(builder = ValuesBuilder.new)
    builder.call do
      row *values
    end
  end
end