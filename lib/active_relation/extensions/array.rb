class Array
  def to_hash
    Hash[*flatten]
  end
  
  def to_sql(formatter = nil)
    "(" + collect { |e| e.to_sql(formatter) }.join(', ') + ")"
  end
  
  def predicate_sql
    "IN"
  end
end