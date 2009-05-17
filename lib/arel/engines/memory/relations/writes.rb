module Arel
  class Insert < Compound
    def eval
      unoperated_rows + [Row.new(self, record.values.collect(&:value))]
    end
  end
end
