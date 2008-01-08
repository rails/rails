class InnerJoinRelation < JoinRelation
  protected
  def join_sql
    "INNER JOIN"
  end
end