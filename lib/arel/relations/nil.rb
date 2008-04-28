module Arel
  class Nil < Relation
    def table_sql(formatter = nil); '' end
    def name; '' end
    def to_s; '' end
    
    def ==(other)
      self.class == other.class
    end
  end
  
end