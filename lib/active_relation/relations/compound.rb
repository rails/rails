module ActiveRelation
  class Compound < Relation
    attr_reader :relation

    delegate :attributes, :attribute, :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit, :offset,
             :to => :relation
  end
end