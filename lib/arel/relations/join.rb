module Arel
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
    
    def joins(formatter = Sql::TableReference.new(self))
      this_join = [
        join_sql,
        if relation2.aggregation?
          relation2.to_sql(formatter)
        else
          relation2.table.table_sql(formatter)
        end,
        ("ON" unless predicates.blank?),
        predicates.collect { |p| p.bind(formatter.christener).to_sql }.join(' AND ')
      ].compact.join(" ")
      [relation1.joins(formatter), this_join, relation2.joins(formatter)].compact.join(" ")
    end
    
    def selects
      (externalize(relation1).selects + externalize(relation2).selects).collect { |s| s.bind(self) }
    end
   
    def name_for(relation)
      @used_names ||= Hash.new(0)
      @relation_names ||= Hash.new do |h, k|
        @used_names[k.name] += 1
        h[k] = k.name + (@used_names[k.name] > 1 ? "_#{@used_names[k.name]}" : '')
      end
      @relation_names[relation]
    end
    
    def table
      relation1.aggregation?? relation1 : relation1.table
    end
      
    delegate :name, :to => :relation1
    
    def relation_for(attribute)
      x = [relation1[attribute], relation2[attribute]].select { |a| a =~ attribute }.min do |a1, a2|
        (attribute % a1).size <=> (attribute % a2).size
      end.relation
      if x.aggregation?
        x
      else
        x.relation_for(attribute) # FIXME @demeter
      end
    end
    
    private
    def externalize(relation)
      Externalizer.new(self, relation)
    end
    
    Externalizer = Struct.new(:christener, :relation) do
      delegate :engine, :to => :relation
      
      def selects
        relation.aggregation?? [] : relation.selects
      end
      
      def attributes
        relation.aggregation?? relation.attributes.collect(&:to_attribute) : relation.attributes
      end
    end
  end
end