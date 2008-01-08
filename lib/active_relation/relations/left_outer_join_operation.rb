class LeftOuterJoinOperation < JoinOperation
  protected
  def relation_class
    LeftOuterJoinRelation
  end
end