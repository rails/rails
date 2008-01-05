class ProjectionRelation < Relation
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
  
  def to_sql(builder = SelectBuilder.new)
    relation.to_sql(builder).call do
      select do
        attributes.collect { |a| a.to_sql(self) }
      end
    end
  end
end