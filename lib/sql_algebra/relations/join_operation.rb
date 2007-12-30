class JoinOperation
  attr_reader :relation1, :relation2
  
  def initialize(relation1, relation2)
    @relation1, @relation2 = relation1, relation2
  end
  
  def on(*predicates)
    JoinRelation.new(relation1, relation2, *predicates)
  end
  
  def ==(other)
    (relation1 == other.relation1 and relation2 == other.relation2) or
      (relation1 == other.relation2 and relation2 == other.relation1)
  end
end