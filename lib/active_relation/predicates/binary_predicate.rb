class BinaryPredicate < Predicate
  attr_reader :attribute1, :attribute2
  
  def initialize(attribute1, attribute2)
    @attribute1, @attribute2 = attribute1, attribute2
  end
  
  def qualify
    self.class.new(attribute1.qualify, attribute2.qualify)
  end
  
  def to_sql(builder = ConditionsBuilder.new)
    builder.call do
      send(predicate_name) do
        attribute1.to_sql(self)
        attribute2.to_sql(self)
      end
    end
  end
end