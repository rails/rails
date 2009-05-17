module Arel
  class Compound < Relation
    delegate :array, :to => :relation
  end
end
