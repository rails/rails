module Arel
  class Nil < Relation
    def table; self end
    def table_sql(formatter = nil); '' end
    def relation_for(attribute); nil end
    def name; '' end
    def to_s; '' end
    
    def ==(other)
      self.class == other.class
    end
  end
  
end