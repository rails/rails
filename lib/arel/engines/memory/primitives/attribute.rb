module Arel
  class Attribute
    def eval(row)
      row[self]
    end
  end
end