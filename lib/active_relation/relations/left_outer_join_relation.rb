class LeftOuterJoinRelation < JoinRelation
  protected
  def join_sql
    "LEFT OUTER JOIN"
  end
end