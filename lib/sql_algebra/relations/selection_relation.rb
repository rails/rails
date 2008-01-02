class SelectionRelation < Relation
  attr_reader :relation, :predicate
  
  def initialize(relation, *predicates)
    @predicate = predicates.shift
    @relation = predicates.empty?? relation : SelectionRelation.new(relation, *predicates)
  end
  
  def ==(other)
    relation == other.relation and predicate == other.predicate
  end
  
  def to_sql(builder = SelectBuilder.new)
    relation.to_sql(builder).call do
      where do
        predicate.to_sql(self)
      end
    end
  end
  
  delegate :[], :to => :relation
end