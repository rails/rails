# frozen_string_literal: true
module Arel
  module Nodes
    class True < Arel::Nodes::Node
      def hash
        self.class.hash
      end

      def eql? other
        self.class == other.class
      end
      alias :== :eql?
    end
  end
end
