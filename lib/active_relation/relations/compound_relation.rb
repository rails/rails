class CompoundRelation < Relation
  delegate :attributes, :attribute, :joins, :selects, :orders, :table, :inserts, :to => :relation
end