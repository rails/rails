module Arel
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
    include Recursion::BaseCase

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
