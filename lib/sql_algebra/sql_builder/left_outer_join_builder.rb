class LeftOuterJoinBuilder < JoinBuilder
  def join_type
    "LEFT OUTER JOIN"
  end
end