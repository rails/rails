class Symbol
  def to_attribute(relation)
    Arel::Attribute.new(relation, self)
  end
end