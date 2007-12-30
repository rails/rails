class TableRelation < Relation
  attr_reader :table
  
  def initialize(table)
    @table = table
  end
  
  def to_sql
    Select.new(:*).from(table)
  end
end