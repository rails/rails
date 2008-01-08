class InsertBuilder < SqlBuilder
  def insert
  end
  
  def into(table)
    @table = table
  end
  
  def columns(&block)
    @columns = ColumnsBuilder.new(&block)
  end
  
  def values(&block)
    @values = ValuesBuilder.new(&block)
  end
  
  def to_s
    [insert_clause,
    into_clause,
    columns_clause,
    values_clause
    ].compact.join("\n")
  end
  
  private
  def insert_clause
    "INSERT"
  end
  
  def into_clause
    "INTO #{quote_table_name(@table)}"
  end
  
  def values_clause
    "VALUES #{@values}" unless @values.blank?
  end
  
  def columns_clause
    "(#{@columns})" unless @columns.blank?
  end
end