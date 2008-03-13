class Array
  def to_hash
    Hash[*flatten]
  end
  
  def to_sql(strategy = nil)
    "(#{collect(&:to_sql).join(', ')})"
  end
end