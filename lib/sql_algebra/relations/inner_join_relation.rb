class InnerJoinRelation < JoinRelation
  def join_type
    :inner_join
  end
end