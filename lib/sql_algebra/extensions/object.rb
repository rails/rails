class Object
  def qualify
    self
  end
  
  def to_sql(builder = EqualsConditionBuilder.new)
    me = self
    builder.call do
      value me
    end
  end
end