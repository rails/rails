# frozen_string_literal: true

module Arel # :nodoc: all
  module WindowPredications
    def over(expr = nil)
      Nodes::Over.new(self, expr)
    end
  end
end
