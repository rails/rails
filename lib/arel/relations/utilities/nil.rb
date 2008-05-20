module Arel
  class Nil < Relation
    include Singleton
    
    def table_sql(formatter = nil); '' end
    def name; '' end
  end
end