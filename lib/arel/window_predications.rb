module Arel
  module WindowPredications

    def over(expr = nil)
      Nodes::Over.new(self, expr)
    end

  end
end