# frozen_string_literal: true
module Arel
  module Nodes
    class Count < Arel::Nodes::Function
      include Math

      def initialize expr, distinct = false, aliaz = nil
        super(expr, aliaz)
        @distinct = distinct
      end
    end
  end
end
