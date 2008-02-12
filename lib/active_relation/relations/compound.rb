module ActiveRelation
  class Compound < Relation
    attr_reader :relation
    delegate :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit,
             :offset, :name, :alias, :aggregation?, :prefix_for, :aliased_prefix_for,
             :to => :relation
    
    def attributes
      relation.attributes.collect { |a| a.bind(self) }
    end
  end
end