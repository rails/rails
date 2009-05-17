module Arel
  class Where < Compound
    def eval
      relation.eval.select { |row| predicate.eval(row) }
    end
  end
end