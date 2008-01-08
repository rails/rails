class LeftOuterJoinRelation < JoinRelation
  protected
  def join_type
    :left_outer_join
  end
end