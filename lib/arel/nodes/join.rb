module Arel
  module Nodes
    class Join < Arel::Nodes::Binary

      alias :single_source :left
      alias :constraint :right

      def initialize single_source, constraint
        super
      end
    end
  end
end
