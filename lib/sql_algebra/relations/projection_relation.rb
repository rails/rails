class ProjectionRelation < Relation
  attr_reader :relation, :attributes
  
  def initialize(relation, *attributes)
    @relation, @attributes = relation, attributes
  end
  
  def ==(other)
    relation == other.relation and attributes.eql?(other.attributes)
  end
end