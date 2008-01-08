class DeleteBuilder < SqlBuilder
  def delete
  end
  
  def from(table)
    @table = table
  end
  
  def where(&block)
    @conditions = ConditionsBuilder.new(&block)
  end
  
  def to_s
    [delete_clause,
    from_clause,
    where_clause
    ].compact.join("\n")
  end
  
  private
  def delete_clause
    "DELETE"
  end
  
  def from_clause
    "FROM #{quote_table_name(@table)}"
  end
  
  def where_clause
    "WHERE #{@conditions}" unless @conditions.blank?
  end
end