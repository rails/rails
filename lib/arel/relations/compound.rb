module Arel
  class Compound < Relation
    attr_reader :relation
    hash_on :relation
    delegate :joins, :selects, :orders, :groupings, :inserts, :taken,
             :skipped, :name, :alias, :aggregation?, :column_for,
             :engine, :name_for, :table, :relation_for, :table_sql,
             :to => :relation
    
    def attributes
      relation.attributes.collect { |a| a.bind(self) }
    end
  end
end