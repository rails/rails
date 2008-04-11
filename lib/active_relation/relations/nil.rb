module ActiveRelation
  class Nil < Relation
    def table_sql; '' end
  end
end