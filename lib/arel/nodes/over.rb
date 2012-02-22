module Arel
  module Nodes

    class Over < Binary
      def initialize(left, right = nil)
        super(left, right)
      end

      def operator; 'OVER' end
    end

  end
end