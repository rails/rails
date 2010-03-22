module Arel
  class Compound
    delegate :array, :to => :relation

    def unoperated_rows
      relation.call.collect { |row| row.bind(self) }
    end
  end
end
