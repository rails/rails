module Arel
  module Nodes
    class Group
      attr_accessor :expr

      def initialize expr
        @expr = expr
      end
    end
  end
end
