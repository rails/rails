module ActiveRelation
  class Compound < Relation
    attr_reader :relation

    delegate :projections, :attributes, :attribute, :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit,
             :offset, :name, :alias, :aggregation?,
             :to => :relation
  end
end