module Arel
  module ObjectExtensions
    def bind(relation)
      Arel::Value.new(self, relation)
    end

    def find_correlate_in(relation)
      bind(relation)
    end

    Object.send(:include, self)
  end
end
