module Arel
  class Compound < Relation
    delegate :table, :table_sql, :array, :to => :relation
  end
end
    