module Arel
  class Join < Relation
    attr_reader :join_sql, :relation1, :relation2, :predicates
    delegate :engine, :name, :to => :relation1
    hash_on :relation1

    def initialize(join_sql, relation1, relation2 = Nil.new, *predicates)
      @join_sql, @relation1, @relation2, @predicates = join_sql, relation1, relation2, predicates
    end
    
    def table_sql(formatter = Sql::TableReference.new(self))
      relation1.externalize.table_sql(formatter)
    end
    
    def joins(environment, formatter = Sql::TableReference.new(environment))
      this_join = [
        join_sql,
        relation2.externalize.table_sql(formatter),
        ("ON" unless predicates.blank?),
        (ons + relation2.externalize.selects).collect { |p| p.bind(environment).to_sql(Sql::WhereClause.new(environment)) }.join(' AND ')
      ].compact.join(" ")
      [relation1.joins(environment), this_join, relation2.joins(environment)].compact.join(" ")
    end

    def attributes
      @attributes ||= (relation1.externalize.attributes +
        relation2.externalize.attributes).collect { |a| a.bind(self) }
    end
    
    def selects
      relation1.externalize.selects
    end
    
    def ons
      @ons ||= @predicates.collect { |p| p.bind(self) }
    end
    
    # TESTME
    def aggregation?
      relation1.aggregation? or relation2.aggregation?
    end
    
    def join?
      true
    end
    
    def ==(other)
      Join       == other.class       and
      predicates == other.predicates  and (
        (relation1 == other.relation1 and relation2 == other.relation2) or
        (relation2 == other.relation1 and relation1 == other.relation2)
      )
    end
  end
  
  class Relation
    def join?
      false
    end
  end
end