Aggregation = Struct.new(:relation) do
  def selects
    []
  end
  
  def table
    relation
  end
  
  def relation_for(attribute)
    relation
  end
  
  def table_sql(formatter = Sql::TableReference.new(relation))
    relation.to_sql(formatter)
  end
  
  def attributes
    relation.attributes.collect(&:to_attribute)
  end
end