module Arel
  module Nodes
    class Having
      attr_accessor :expr

      def initialize expr
        @expr = expr
      end
    end
  end
end
