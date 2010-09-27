module Arel
  module Nodes
    class Function < Arel::Nodes::Node
      include Arel::Expression
      attr_accessor :expressions, :alias

      def initialize expr, aliaz = nil
        @expressions = expr
        @alias       = aliaz
      end

      def as aliaz
        self.alias = SqlLiteral.new(aliaz)
        self
      end
    end
  end
end
