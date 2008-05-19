module Arel
  class Compound < Relation
    attr_reader :relation
    hash_on :relation
    delegate :joins, :wheres, :join?, :inserts, :taken,
             :skipped, :name, :aggregation?, :column_for,
             :engine, :table, :table_sql,
             :to => :relation
    
    def attributes
      @attributes ||= relation.attributes.collect { |a| a.bind(self) }
    end
    
    def wheres
      @wheres ||= relation.wheres.collect { |w| w.bind(self) }
    end
    
    def groupings
      @groupings ||= relation.groupings.collect { |g| g.bind(self) }
    end
    
    def orders
      @orders ||= relation.orders.collect { |o| o.bind(self) }
    end
  end
end