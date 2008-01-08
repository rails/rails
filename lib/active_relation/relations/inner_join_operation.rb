class InnerJoinOperation < JoinOperation
  protected
  def relation_class
    InnerJoinRelation
  end
end