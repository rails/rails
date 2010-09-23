module Arel
  module Nodes
    class Count < Arel::Nodes::Function

      attr_accessor :distinct

      def initialize expr, distinct = false, aliaz = nil
        super(expr, aliaz)
        @distinct = distinct
      end
    end
  end
end
