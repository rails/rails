# frozen_string_literal: true
module Arel
  module Nodes
    class NamedFunction < Arel::Nodes::Function
      attr_accessor :name

      def initialize name, expr, aliaz = nil
        super(expr, aliaz)
        @name = name
      end

      def hash
        super ^ @name.hash
      end

      def eql? other
        super && self.name == other.name
      end
      alias :== :eql?
    end
  end
end
