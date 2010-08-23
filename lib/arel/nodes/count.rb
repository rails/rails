module Arel
  module Nodes
    class Count
      attr_accessor :expressions, :distinct

      def initialize expr, distinct = false
        @expressions = expr
        @distinct    = distinct
      end
    end
  end
end
