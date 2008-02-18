module ActiveRelation
  class Join < Relation
    attr_reader :join_sql, :relation1, :relation2, :predicates

    def initialize(join_sql, relation1, relation2, *predicates)
      @join_sql, @relation1, @relation2, @predicates = join_sql, relation1, relation2, predicates
    end

    def ==(other)
      self.class == other.class       and
      predicates == other.predicates  and (
        (relation1 == other.relation1 and relation2 == other.relation2) or
        (relation2 == other.relation1 and relation1 == other.relation2)
      )
    end

    def qualify
      descend(&:qualify)
    end
    
    def attributes
      [
        relation1.attributes.collect(&:to_attribute),
        relation2.attributes.collect(&:to_attribute),
      ].flatten.collect { |a| a.bind(self) }
    end
    
    def prefix_for(attribute)
      relation1.aliased_prefix_for(attribute) or
      relation2.aliased_prefix_for(attribute)
    end
    alias_method :aliased_prefix_for, :prefix_for

    protected
    def joins
      right_table_sql = relation2.aggregation?? relation2.to_sql(Sql::Aggregation.new) : relation2.send(:table_sql)
      this_join = [join_sql, right_table_sql, "ON", predicates.collect { |p| p.bind(self).to_sql(Sql::Predicate.new) }.join(' AND ')].join(" ")
      [relation1.joins, relation2.joins, this_join].compact.join(" ")
    end

    def selects
      [
        (relation1.send(:selects) unless relation1.aggregation?),
        (relation2.send(:selects) unless relation2.aggregation?)
      ].compact.flatten
    end
   
    def table_sql
      relation1.aggregation?? relation1.to_sql(Sql::Aggregation.new) : relation1.send(:table_sql)
    end
    
    def descend(&block)
      Join.new(join_sql, relation1.descend(&block), relation2.descend(&block), *predicates.collect(&block))
    end
  end
end