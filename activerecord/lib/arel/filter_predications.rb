# frozen_string_literal: true

module Arel # :nodoc: all
  module FilterPredications
    def filter(expr)
      Nodes::Filter.new(self, expr)
    end
  end
end
