class InsertionRelation < CompoundRelation
  attr_reader :relation, :tuple
  
  def initialize(relation, tuple)
    @relation, @tuple = relation, tuple
  end
  
  def to_sql(builder = InsertBuilder.new)
    builder.call do
      insert
      into table
      columns do
        tuple.keys.each { |attribute| attribute.to_sql(self) }
      end
      values do
        inserts.each { |insert| insert.to_sql(self) }
      end
    end
  end

  def ==(other)
    relation == other.relation and tuple == other.tuple
  end
  
  protected
  def inserts
    relation.inserts + [tuple]
  end
end