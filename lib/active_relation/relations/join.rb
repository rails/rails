class Join
  attr_reader :relation1, :relation2, :predicates, :join_type
  
  def initialize(relation1, relation2, predicates, join_type)
    @relation1, @relation2, @predicates, @join_type = relation1, relation2, predicates, join_type
  end
  
  def to_sql(builder = JoinsBuilder.new)
    builder.call do
      send(join_type, relation2.table) do
        predicates.each { |p| p.to_sql(self) }
      end
    end
  end
end