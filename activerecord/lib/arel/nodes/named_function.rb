# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class NamedFunction < Arel::Nodes::Function
      attr_accessor :name

      def initialize(name, expr)
        super(expr)
        @name = name
      end

      def hash
        super ^ @name.hash
      end

      def eql?(other)
        super && self.name == other.name
      end
      alias :== :eql?
    end
  end
end
