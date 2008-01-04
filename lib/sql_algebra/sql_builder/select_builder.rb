class SelectBuilder < SqlBuilder  
  def select(&block)
    @selects = SelectsBuilder.new(&block)
  end
  
  def from(table, &block)
    @table = table
    @joins = JoinsBuilder.new(&block)
  end
  
  def where(&block)
    @conditions ||= ConditionsBuilder.new
    @conditions.call(&block)
  end
  
  def order_by(&block)
    @orders = OrderBuilder.new(&block)
  end
  
  def limit(i, offset = nil)
    @limit = i
    offset(offset) if offset
  end
  
  def offset(i)
    @offset = i
  end
  
  def to_s
    [select_clause,
    from_clause,
    where_clause,
    order_by_clause,
    limit_clause,
    offset_clause].compact.join("\n")
  end
  
  private
  def select_clause
    "SELECT #{@selects}" unless @selects.blank?
  end
  
  def from_clause
    "FROM #{@table} #{@joins}" unless @table.blank?
  end
  
  def where_clause
    "WHERE #{@conditions}" unless @conditions.blank?
  end
  
  def order_by_clause
    "ORDER BY #{@orders}" unless @orders.blank?
  end
  
  def limit_clause
    "LIMIT #{@limit}" unless @limit.blank?
  end
  
  def offset_clause
    "OFFSET #{@offset}" unless @offset.blank?
  end
end