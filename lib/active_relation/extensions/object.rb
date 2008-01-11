class Object
  include ActiveRelation::SqlBuilder
  
  def qualify
    self
  end
  
  def to_sql(options = {})
    options.reverse_merge!(:quote => true)
    options[:quote] ? quote(self) : self
  end
end