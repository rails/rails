module ActiveRelation
  class Compound < Relation
    attr_reader :relation
    delegate :joins, :selects, :orders, :groupings, :table_sql, :inserts, :limit,
             :offset, :name, :alias, :aggregation?,
             :to => :relation
    
    def attributes
      relation.attributes.collect { |a| a.substitute(self) }
    end
    
    protected
    def attribute_for_name(name)
      (a = relation[name]) && a.substitute(self)
    end
    
    def attribute_for_attribute(attribute)
      attribute.relation == self ? attribute : (a = relation[attribute]) && a.substitute(self)
    end
    
    def attribute_for_expression(expression)
      expression.relation == self ? expression : (a = relation[expression]) && a.substitute(self)
    end
  end
end