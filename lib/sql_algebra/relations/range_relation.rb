class RangeRelation < Relation
  attr_reader :relation, :range
  
  def initialize(relation, range)
    @relation, @range = relation, range
  end
  
  def ==(other)
    relation == other.relation and range == other.range
  end
  
  def to_sql(builder = SelectBuilder.new)
    relation.to_sql(builder).call do
      limit range.last - range.first + 1
      offset range.first
    end
  end
end