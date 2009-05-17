module Arel
  class Compound < Relation
    delegate :array, :to => :relation

    def unoperated_rows
      relation.call.collect { |row| row.bind(self) }
    end
  end
end
