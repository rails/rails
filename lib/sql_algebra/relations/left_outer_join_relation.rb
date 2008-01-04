class LeftOuterJoinRelation < JoinRelation
  def join_type
    :left_outer_join
  end
end