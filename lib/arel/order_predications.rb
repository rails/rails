module Arel
  module OrderPredications

    def asc
      Nodes::Ordering.new self, :asc
    end

    def desc
      Nodes::Ordering.new self, :desc
    end

  end
end
