class OrderRelation < Relation
  attr_reader :relation, :attributes
  
  def initialize(relation, *attributes)
    @relation, @attributes = relation, attributes
  end
  
  def ==(other)
    relation == other.relation and attributes.eql?(other.attributes)
  end
  
  def to_sql(builder = SelectBuilder.new)
    relation.to_sql(builder).call do
      attributes.each do |attribute|
        order_by do
          attribute.to_sql(self)
        end
      end
    end
  end
end