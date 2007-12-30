class JoinRelation < Relation
  attr_reader :relation1, :relation2, :predicates
  
  def initialize(relation1, relation2, *predicates)
    @relation1, @relation2, @predicates = relation1, relation2, predicates
  end
  
  def ==(other)
    predicates == other.predicates and
      ((relation1 == other.relation1 and relation2 == other.relation2) or
      (relation2 == other.relation1 and relation1 == other.relation2))
  end
end