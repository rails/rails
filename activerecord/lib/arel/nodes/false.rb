# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class False < Arel::Nodes::NodeExpression
      def hash
        self.class.hash
      end

      def eql?(other)
        self.class == other.class
      end
      alias :== :eql?
    end
  end
end
