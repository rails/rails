module ActiveRelation
  module Relations
    class Compound < Base
      attr_reader :relation
  
      delegate :attributes, :attribute, :joins, :selects, :orders, :table, :inserts, :limit, :offset, :alias, :to => :relation
    end
  end
end