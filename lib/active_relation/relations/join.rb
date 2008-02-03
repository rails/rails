module ActiveRelation
  class Join < Relation
    attr_reader :join_sql, :relation1, :relation2, :predicates

    def initialize(join_sql, relation1, relation2, *predicates)
      @join_sql, @relation1, @relation2, @predicates = join_sql, relation1, relation2, predicates
    end

    def ==(other)
      predicates == other.predicates and
        ((relation1 == other.relation1 and relation2 == other.relation2) or
        (relation2 == other.relation1 and relation1 == other.relation2))
    end

    def qualify
      Join.new(join_sql, relation1.qualify, relation2.qualify, *predicates.collect(&:qualify))
    end
    
    def attributes
      [
        relation1.aggregation?? relation1.attributes.collect(&:to_attribute) : relation1.attributes,
        relation2.aggregation?? relation2.attributes.collect(&:to_attribute) : relation2.attributes,
      ].flatten
    end

    protected
    def joins
      [relation1.joins, relation2.joins, join].compact.join(" ")
    end

    def selects
      [
        (relation1.send(:selects) unless relation1.aggregation?),
        (relation2.send(:selects) unless relation2.aggregation?)
      ].compact.flatten
    end
    
    def attribute_for_name(name)
      relation1[name] || relation2[name]
    end

    def attribute_for_attribute(attribute)
      relation1[attribute] || relation2[attribute]
    end
   
    def table_sql
      relation1.aggregation?? relation1.to_sql(Sql::Aggregation.new) : relation1.send(:table_sql)
    end
    
    private
    def join
      [join_sql, right_table_sql, "ON", predicates.collect { |p| p.to_sql(Sql::Predicate.new) }.join(' AND ')].join(" ")
    end
    
    def right_table_sql
      relation2.aggregation?? relation2.to_sql(Sql::Aggregation.new) : relation2.send(:table_sql)
    end
  end
end