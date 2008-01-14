module ActiveRelation
  module Relations
    class Compound < Base
      attr_reader :relation
  
      delegate :attributes, :attribute, :joins, :selects, :orders, :table_sql, :inserts, :limit, :offset, :to => :relation
    end
  end
end