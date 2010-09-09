module Arel
  module Nodes
    class Values
      attr_accessor :expressions

      def initialize exprs
        @expressions = exprs
      end
    end
  end
end
