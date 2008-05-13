module Arel
  class Compound < Relation
    attr_reader :relation
    hash_on :relation
    delegate :joins, :selects, :orders, :groupings, :inserts, :taken,
             :skipped, :name, :aggregation?, :column_for,
             :engine, :table, :relation_for, :table_sql,
             :to => :relation
    
    def attributes
      @attributes ||= relation.attributes.collect { |a| a.bind(self) }
    end
  end
end