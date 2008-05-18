module Arel
  class Nil < Relation
    def table_sql(formatter = nil); '' end
    def relation_for(attribute); nil end
    def name; '' end

    def ==(other)
      Nil == other.class
    end
  end
end