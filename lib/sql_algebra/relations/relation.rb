class Relation
  def *(other)
    JoinOperation.new(self, other)
  end
  
  def [](attribute_name)
    Attribute.new(self, attribute_name)
  end
  
  def include?(attribute)
    RelationInclusionPredicate.new(attribute, self)
  end
end