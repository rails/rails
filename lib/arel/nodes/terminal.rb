module Arel
  module Nodes
    class Distinct < Arel::Nodes::Node
      def hash
        self.class.hash
      end

      def eql? other
        self.class == other.class
      end
    end
  end
end
