module Arel
  module Nodes
    class Offset
      attr_accessor :value

      def initialize value
        @value = value
      end
    end
  end
end
