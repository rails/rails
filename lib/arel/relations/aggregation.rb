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
      relation.to_sql(formatter)
    end
  
    def attributes
      @attributes ||= relation.attributes.collect(&:to_attribute)
    end
    
    def ==(other)
      self.class    == other.class and
      self.relation == other.relation
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