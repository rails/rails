class CompoundRelation < Relation
  delegate :attributes, :attribute, :joins, :select, :orders, :table, :to => :relation
end