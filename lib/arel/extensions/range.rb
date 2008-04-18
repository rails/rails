class Range
  def to_sql(formatter = nil)
    formatter.range self.begin, self.end
  end
  
  def inclusion_predicate_sql
    "BETWEEN"
  end
end