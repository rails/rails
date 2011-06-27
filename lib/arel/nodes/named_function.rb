module Arel
  module Nodes
    class NamedFunction < Arel::Nodes::Function
      attr_accessor :name

      def initialize name, expr, aliaz = nil
        super(expr, aliaz)
        @name = name
      end
    end
  end
end
