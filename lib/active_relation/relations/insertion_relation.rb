class InsertionRelation < CompoundRelation
  attr_reader :record
  
  def initialize(relation, record)
    @relation, @record = relation, record
  end

  def to_sql(options = {})
    [
      "INSERT",
      "INTO #{quote_table_name(table)}",
      "(#{record.keys.collect(&:to_sql).join(', ')})",
      "VALUES #{inserts.collect(&:to_sql).join(', ')}"
    ].join("\n")
  end  

  protected
  def inserts
    relation.inserts + [record]
  end
end