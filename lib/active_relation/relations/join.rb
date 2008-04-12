module ActiveRelation
  class Join < Relation
    attr_reader :join_sql, :relation1, :relation2, :predicates
    
    delegate :engine, :to => :relation1

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
    
    def attributes
      (externalize(relation1).attributes +
        externalize(relation2).attributes).collect { |a| a.bind(self) }
    end
    
    def prefix_for(attribute)
      externalize(relation1).prefix_for(attribute) or
      externalize(relation2).prefix_for(attribute)
    end
    
    def joins
      this_join = [
        join_sql,
        externalize(relation2).table_sql,
        ("ON" unless predicates.blank?),
        predicates.collect { |p| p.bind(self).to_sql }.join(' AND ')
      ].compact.join(" ")
      [relation1.joins, relation2.joins, this_join].compact.join(" ")
    end

    def selects
      externalize(relation1).selects + externalize(relation2).selects
    end
   
    def table_sql
      externalize(relation1).table_sql
    end
    
    private
    def externalize(relation)
      Externalizer.new(relation)
    end
    
    Externalizer = Struct.new(:relation) do
      delegate :engine, :to => :relation
      
      def table_sql
        relation.aggregation?? relation.to_sql(Sql::TableReference.new(engine)) : relation.table_sql
      end
      
      def selects
        relation.aggregation?? [] : relation.selects
      end
      
      def attributes
        relation.aggregation?? relation.attributes.collect(&:to_attribute) : relation.attributes
      end
      
      def prefix_for(attribute)
        if relation[attribute]
          relation.alias?? relation.alias : relation.prefix_for(attribute)
        end
      end
    end
  end
end