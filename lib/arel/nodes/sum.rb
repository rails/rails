module Arel
  module Nodes
    class Sum
      attr_accessor :expressions, :alias

      def initialize expr, aliaz = nil
        @expressions = expr
        @alias       = aliaz
      end
    end
  end
end
