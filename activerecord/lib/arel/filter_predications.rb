# frozen_string_literal: true

# :markup: markdown
module Arel # :nodoc: all
  module FilterPredications
    def filter(expr)
      Nodes::Filter.new(self, expr)
    end
  end
end
