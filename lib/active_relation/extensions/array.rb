class Array
  def to_hash
    Hash[*flatten]
  end
  
  def to_sql(formatter = Sql::SelectExpression.new)
    formatter.array self
  end
end