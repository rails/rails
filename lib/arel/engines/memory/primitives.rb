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
end