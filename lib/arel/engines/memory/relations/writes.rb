module Arel
  class Insert < Action
    def eval
      unoperated_rows + [Row.new(self, record.values.collect(&:value))]
    end
  end
end
