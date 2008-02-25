module ActiveRelation
  class Compound < Relation
    attr_reader :relation
    delegate :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit,
             :offset, :name, :alias, :aggregation?, :alias?, :prefix_for, :column_for,
             :to => :relation
    
    def attributes
      relation.attributes.collect { |a| a.bind(self) }
    end
    
    def qualify
      descend(&:qualify)
    end
  end
end