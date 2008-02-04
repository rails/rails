module ActiveRelation
  class Compound < Relation
    attr_reader :relation
    delegate :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit,
             :offset, :name, :alias, :aggregation?, :prefix_for, :aliased_prefix_for,
             :to => :relation
    
    def attributes
      relation.attributes.collect { |a| a.substitute(self) }
    end
    
    protected
    def attribute_for_name(name)
      relation[name].substitute(self) rescue nil
    end
  end
end