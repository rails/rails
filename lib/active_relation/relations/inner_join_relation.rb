class InnerJoinRelation < JoinRelation
  protected
  def join_type
    :inner_join
  end
end