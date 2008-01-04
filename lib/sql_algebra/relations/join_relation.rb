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
  
  def joins
    relation1.joins + relation2.joins + [Join.new(relation1, relation2, predicates, join_type)]
  end
  
  def selects
    relation1.selects + relation2.selects
  end
  
  def attributes
    relation1.attributes + relation2.attributes
  end
  
  def attribute(name)
    relation1[name] || relation2[name]
  end
  
  protected
  delegate :table, :to => :relation1
end