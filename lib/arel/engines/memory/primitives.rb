module Arel
  class Attribute
    def eval(row)
      row[self]
    end
  end

  class Value
    def eval(row)
      value
    end
  end

  class Ordering
    def eval(row1, row2)
      (attribute.eval(row1) <=> attribute.eval(row2)) * direction
    end
  end

  class Descending < Ordering
    def direction; -1 end
  end

  class Ascending < Ordering
    def direction; 1 end
  end
end
