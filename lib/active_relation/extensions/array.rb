class Array
  def to_hash
    Hash[*flatten]
  end
  
  def to_sql(strategy = Sql::SelectExpression.new)
    strategy.array self
  end
end