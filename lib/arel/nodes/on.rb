module Arel
  module Nodes
    class On
      attr_accessor :expr

      def initialize expr
        @expr = expr
      end
    end
  end
end
