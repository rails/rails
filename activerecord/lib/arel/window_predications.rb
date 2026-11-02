# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module WindowPredications
    def over(expr = nil)
      Nodes::Over.new(self, expr)
    end
  end
end
