class Attribute
  attr_reader :relation, :attribute_name, :aliaz
  
  def initialize(relation, attribute_name, aliaz = nil)
    @relation, @attribute_name, @aliaz = relation, attribute_name, aliaz
  end
  
  def eql?(other)
    relation == other.relation and attribute_name == other.attribute_name
  end
  
  def ==(other)
    EqualityPredicate.new(self, other)
  end
  
  def <(other)
    LessThanPredicate.new(self, other)
  end
  
  def <=(other)
    LessThanOrEqualToPredicate.new(self, other)
  end
  
  def >(other)
    GreaterThanPredicate.new(self, other)
  end
  
  def >=(other)
    GreaterThanOrEqualToPredicate.new(self, other)
  end
  
  def =~(regexp)
    MatchPredicate.new(self, regexp)
  end
  
  def to_sql(builder = SelectsBuilder.new)
    builder.call do
      column relation.table, attribute_name, aliaz
    end
  end
end