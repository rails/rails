module Arel
  class Join < Relation
    attributes :join_sql, :relation1, :relation2, :predicates
    deriving :==
    delegate :engine, :name, :to => :relation1
    hash_on :relation1

    def initialize(join_sql, relation1, relation2 = Nil.instance, *predicates)
      @join_sql, @relation1, @relation2, @predicates = join_sql, relation1, relation2, predicates
    end
    
    def table_sql(formatter = Sql::TableReference.new(self))
      relation1.externalize.table_sql(formatter)
    end
    
    def joins(environment, formatter = Sql::TableReference.new(environment))
      @joins ||= begin
        this_join = [
          join_sql,
          relation2.externalize.table_sql(formatter),
          ("ON" unless predicates.blank?),
          (ons + relation2.externalize.wheres).collect { |p| p.bind(environment).to_sql(Sql::WhereClause.new(environment)) }.join(' AND ')
        ].compact.join(" ")
        [relation1.joins(environment), this_join, relation2.joins(environment)].compact.join(" ")
      end
    end

    def attributes
      @attributes ||= (relation1.externalize.attributes +
        relation2.externalize.attributes).collect { |a| a.bind(self) }
    end
    
    def wheres
      # TESTME bind to self?
      relation1.externalize.wheres
    end
    
    def ons
      @ons ||= @predicates.collect { |p| p.bind(self) }
    end
    
    # TESTME
    def externalizable?
      relation1.externalizable? or relation2.externalizable?
    end
    
    def join?
      true
    end
  end
  
  class Relation
    def join?
      false
    end
  end
end