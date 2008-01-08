class CompoundRelation < Relation
  attr_reader :relation
  
  delegate :attributes, :attribute, :joins, :selects, :orders, :table, :inserts, :limit, :offset, :to => :relation
end