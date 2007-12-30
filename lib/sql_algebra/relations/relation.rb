class Relation
  def <=>(other)
    InnerJoinOperation.new(self, other)
  end
  
  def <<(other)
    LeftOuterJoinOperation.new(self, other)
  end
  
  def [](index)
    case index
    when Symbol
      Attribute.new(self, index)
    when Range
      RangeRelation.new(self, index)
    end
  end
  
  def include?(attribute)
    RelationInclusionPredicate.new(attribute, self)
  end
  
  def select(*predicates)
    SelectionRelation.new(self, *predicates)
  end
  
  def project(*attributes)
    ProjectionRelation.new(self, *attributes)
  end
  
  def order(*attributes)
    OrderRelation.new(self, *attributes)
  end
end