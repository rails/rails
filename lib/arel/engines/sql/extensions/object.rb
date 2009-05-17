class Object
  def to_sql(formatter)
    formatter.scalar self
  end

  def equality_predicate_sql
    '='
  end
end
