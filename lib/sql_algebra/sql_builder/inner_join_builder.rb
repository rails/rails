class InnerJoinBuilder < JoinBuilder
  def join_type
    "INNER JOIN"
  end
end