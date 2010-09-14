module Arel
  module Nodes
    class Values
      attr_accessor :expressions, :columns

      def initialize exprs, columns = []
        @expressions = exprs
        @columns = columns
      end
    end
  end
end
