module Arel
  class Where < Compound
    def eval
      relation.eval.select { |row| predicate.eval(row) }
    end
  end
  
  class Order < Compound
    def eval
      relation.eval.sort do |row1, row2|
        ordering = orderings.detect { |o| o.eval(row1, row2) != 0 } || orderings.last
        ordering.eval(row1, row2)
      end
    end
  end
  
  class Project < Compound
    def eval
      relation.eval.collect { |r| r.slice(*projections) }
    end
  end
  
  class Take < Compound
    def eval
      relation.eval[0, taken]
    end
  end
  
  class Skip < Compound
    def eval
      relation.eval[skipped..-1]
    end
  end
  
  class Group < Compound
    def eval
      raise NotImplementedError
    end
  end
end