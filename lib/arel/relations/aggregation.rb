module Arel
  class Aggregation < Compound
    include Recursion::BaseCase

    def initialize(relation)
      @relation = relation
    end
    
    def selects
      []
    end
  
    def table_sql(formatter = Sql::TableReference.new(relation))
      formatter.select relation.select_sql, self
    end
  
    def attributes
      @attributes ||= relation.attributes.collect(&:to_attribute).collect { |a| a.bind(self) }
    end
    
    def name
      relation.name + '_aggregation'
    end
    
    def ==(other)
      Aggregation   === other and
      self.relation ==  other.relation
    end
  end
  
  class Relation
    def externalize
      @externalized ||= aggregation?? Aggregation.new(self) : self
    end
    
    def aggregation?
      false
    end
  end
end