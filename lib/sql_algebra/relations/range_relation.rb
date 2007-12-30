class RangeRelation < Relation
  attr_reader :relation, :range
  
  def initialize(relation, range)
    @relation, @range = relation, range
  end
  
  def ==(other)
    relation == other.relation and range == other.range
  end
end