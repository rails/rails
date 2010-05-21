module Arel
  class Where < Compound
    def eval
      unoperated_rows.select { |row| predicates.all? { |p| p.eval(row) } }
    end
  end

  class Order < Compound
    def eval
      unoperated_rows.sort do |row1, row2|
        ordering = orders.detect { |o| o.eval(row1, row2) != 0 } || orders.last
        ordering.eval(row1, row2)
      end
    end
  end

  class Project < Compound
    def eval
      unoperated_rows.collect { |r| r.slice(*projections) }
    end
  end

  class Take < Compound
    def eval
      unoperated_rows[0, taken]
    end
  end

  class Skip < Compound
    def eval
      unoperated_rows[skipped..-1]
    end
  end

  class From < Compound
    def eval
      unoperated_rows[sources..-1]
    end
  end

  class Group < Compound
    def eval
      raise NotImplementedError
    end
  end

  class Alias < Compound
    def eval
      unoperated_rows
    end
  end

  class Join
    def eval
      result = []
      relation1.call.each do |row1|
        relation2.call.each do |row2|
          combined_row = row1.combine(row2, self)
          if predicates.all? { |p| p.eval(combined_row) }
            result << combined_row
          end
        end
      end
      result
    end
  end
end
