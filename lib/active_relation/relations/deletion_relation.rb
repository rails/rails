class DeletionRelation < CompoundRelation
  attr_reader :relation
  
  def ==(other)
    relation == other.relation
  end
  
  def initialize(relation)
    @relation = relation
  end
  
  def to_sql(builder = DeleteBuilder.new)
    builder.call do
      delete
      from table
      where do
        selects.each { |s| s.to_sql(self) }
      end
    end
  end
  
end