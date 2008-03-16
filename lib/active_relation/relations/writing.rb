module ActiveRelation
  class Writing < Compound
    abstract :call, :to_sql
  end
end