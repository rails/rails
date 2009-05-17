module Arel
  class Compound < Relation
    delegate :table, :table_sql, :to => :relation
  end
end
    