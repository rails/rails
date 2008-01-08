class ProjectionRelation < CompoundRelation
  attr_reader :relation, :attributes
  
  def initialize(relation, *attributes)
    @relation, @attributes = relation, attributes
  end
  
  def ==(other)
    relation == other.relation and attributes.eql?(other.attributes)
  end
  
  def qualify
    ProjectionRelation.new(relation.qualify, *attributes.collect(&:qualify))
  end
end