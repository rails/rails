module Arel
  module Nodes

    class Extract < Arel::Nodes::Unary
      include Arel::Expression
      include Arel::Predications

      attr_accessor :field
      attr_accessor :alias

      def initialize expr, field, aliaz = nil
        super(expr)
        @field = field
        @alias = aliaz && SqlLiteral.new(aliaz)
      end

      def as aliaz
        self.alias = SqlLiteral.new(aliaz)
        self
      end
    end
  end
end
