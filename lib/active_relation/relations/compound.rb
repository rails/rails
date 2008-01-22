module ActiveRelation
  class Compound < Relation
    attr_reader :relation

    delegate :projections, :attribute, :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit, :offset, :name, :alias,
             :to => :relation
  end
end