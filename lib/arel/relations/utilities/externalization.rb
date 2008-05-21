module Arel
  class Externalization < Compound
    attributes :relation
    deriving :initialize, :==
    include Recursion::BaseCase

    def wheres
      []
    end
  
    def table_sql(formatter = Sql::TableReference.new(relation))
      formatter.select relation.select_sql, self
    end
  
    def attributes
      @attributes ||= relation.attributes.collect(&:to_attribute).collect { |a| a.bind(self) }
    end
    
    # REMOVEME
    def name
      relation.name + '_external'
    end
  end
  
  class Relation
    def externalize
      @externalized ||= externalizable?? Externalization.new(self) : self
    end
    
    def externalizable?
      false
    end
  end
end