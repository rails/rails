class TableRelation < Relation
  attr_reader :table
  
  def initialize(table)
    @table = table
  end
  
  def to_sql
    SelectBuilder.new do
      select :*
      from table
    end
  end
end