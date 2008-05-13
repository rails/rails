module Arel
  class Join < Relation
    attr_reader :join_sql, :relation1, :relation2, :predicates
    delegate :engine, :name, :to => :relation1
    hash_on :relation1

    def initialize(join_sql, relation1, relation2 = Nil.new, *predicates)
      @join_sql, @relation1, @relation2, @predicates = join_sql, relation1, relation2, predicates
    end

    def ==(other)
      self.class == other.class       and
      predicates == other.predicates  and (
        (relation1 == other.relation1 and relation2 == other.relation2) or
        (relation2 == other.relation1 and relation1 == other.relation2)
      )
    end
    
    def joins(environment, formatter = Sql::TableReference.new(environment))
      this_join = [
        join_sql,
        externalize(relation2).table_sql(formatter),
        ("ON" unless predicates.blank?),
        predicates.collect { |p| p.bind(environment).to_sql }.join(' AND ')
      ].compact.join(" ")
      [relation1.joins(environment), this_join, relation2.joins(environment)].compact.join(" ")
    end

    def attributes
      @attributes ||= (externalize(relation1).attributes +
        externalize(relation2).attributes).collect { |a| a.bind(self) }
    end
    
    def selects
      (externalize(relation1).selects + externalize(relation2).selects).collect { |s| s.bind(self) }
    end
   
    def table
      externalize(relation1).table
    end
    
    def table_sql(formatter = Sql::TableReference.new(self))
      externalize(table).table_sql(formatter)
    end
    
    def relation_for(attribute)
      [
        externalize(relation1).relation_for(attribute),
        externalize(relation2).relation_for(attribute)
      ].max do |r1, r2|
        a1, a2 = r1 && r1[attribute], r2 && r2[attribute]
        attribute / a1 <=> attribute / a2
      end
    end
    
    private
    # FIXME - make instance method
    def externalize(relation)
      relation.aggregation?? Aggregation.new(relation) : relation
    end
  end
end