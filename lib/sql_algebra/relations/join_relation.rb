class JoinRelation < Relation
  attr_reader :relation1, :relation2, :predicates
  
  def initialize(relation1, relation2, *predicates)
    @relation1, @relation2, @predicates = relation1, relation2, predicates
  end
  
  def ==(other)
    predicates == other.predicates and
      ((relation1 == other.relation1 and relation2 == other.relation2) or
      (relation2 == other.relation1 and relation1 == other.relation2))
  end
  
  def to_sql(builder = SelectBuilder.new)
    relation2.to_sql(translate_from_to_inner_join_on_predicates(relation1.to_sql(builder)))
  end
  
  private
  # translate 'from' to 'inner join on <predicates>'
  def translate_from_to_inner_join_on_predicates(builder)
    schmoin_name, schmredicates = join_name, predicates
    SqlBuilderAdapter.new(builder) do |builder|
      define_method :from do |table|
        builder.call do
          send(schmoin_name, table) do
            schmredicates.each do |predicate|
              predicate.to_sql(self)
            end
          end
        end
      end
    end
  end
end