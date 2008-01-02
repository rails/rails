class TableRelation < Relation
  attr_reader :table
  
  def initialize(table)
    @table = table
  end
  
  def to_sql(builder = SelectBuilder.new)
    builder.call do
      select { all }
      from table
    end
  end
end