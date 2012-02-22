module Arel
  module Nodes
    class Function < Arel::Nodes::Node
      include Arel::Expression
      include Arel::Predications
      include Arel::WindowPredications
      attr_accessor :expressions, :alias, :distinct

      def initialize expr, aliaz = nil
        @expressions = expr
        @alias       = aliaz && SqlLiteral.new(aliaz)
        @distinct    = false
      end

      def as aliaz
        self.alias = SqlLiteral.new(aliaz)
        self
      end
    end

    %w{
      Sum
      Exists
      Max
      Min
      Avg
    }.each do |name|
      const_set(name, Class.new(Function))
    end
  end
end
