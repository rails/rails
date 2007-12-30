class RelationInclusionPredicate < Predicate
  attr_reader :attribute, :relation
  
  def initialize(attribute, relation)
    @attribute, @relation = attribute, relation
  end
  
  def ==(other)
    super and attribute == other.attribute and relation == other.relation
  end
end