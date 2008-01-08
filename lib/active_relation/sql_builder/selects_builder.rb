class SelectsBuilder < ColumnsBuilder
  def all
    @columns << :*
  end
  
  def column(table, column, aliaz = nil)
    @columns << "#{quote_table_name(table)}.#{quote_column_name(column)}" + (aliaz ? " AS #{quote(aliaz)}" : '')
  end
end