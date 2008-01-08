class EqualityPredicate < BinaryPredicate
  def ==(other)
    self.class == other.class and
      ((attribute1.eql?(other.attribute1) and attribute2.eql?(other.attribute2)) or
       (attribute1.eql?(other.attribute2) and attribute2.eql?(other.attribute1)))
  end
    
  protected
  def predicate_sql
    '='
  end
end