class SelectionRelation < CompoundRelation
  attr_reader :relation, :predicate
  
  def initialize(relation, *predicates)
    @predicate = predicates.shift
    @relation = predicates.empty?? relation : SelectionRelation.new(relation, *predicates)
  end
  
  def ==(other)
    relation == other.relation and predicate == other.predicate
  end
  
  def selects
    [predicate]
  end
end