module Arel
  class Nil < Relation
    # XXX
    include Recursion::BaseCase
    
    def table_sql(formatter = nil); '' end
    def relation_for(attribute); nil end
    def name; '' end
    def to_s; '' end
    
    def ==(other)
      self.class == other.class
    end
  end
  
end