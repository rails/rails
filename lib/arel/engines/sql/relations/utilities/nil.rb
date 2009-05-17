module Arel
  class Nil < Relation
    def table_sql(formatter = nil); '' end
    def name; '' end
  end
end
